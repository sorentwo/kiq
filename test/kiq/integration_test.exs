defmodule Kiq.IntegrationTest do
  use Kiq.Case

  alias Kiq.{Integration, Pool, Timestamp}
  alias Kiq.Integration.Worker
  alias Kiq.Client.Introspection

  @identity "ident:1234"

  setup do
    {:ok, _pid} = start_supervised({Integration, identity: @identity, pool_size: 1})

    :ok = Integration.clear()
  end

  def capture_log(opts \\ [], fun) do
    {sleep, opts} = Keyword.pop(opts, :sleep, 50)

    ExUnit.CaptureLog.capture_log(opts, fn ->
      fun.()
      Process.sleep(sleep)
      Logger.flush()
    end)
  end

  describe "Enqueuing & Running" do
    test "enqueuing and executing jobs successfully" do
      logged =
        capture_log(fn ->
          for index <- 1..5 do
            enqueue_job(index)

            assert_receive {:processed, ^index}
          end
        end)

      assert logged =~ ~s("status":"started")
      assert logged =~ ~s("status":"success")
      refute logged =~ ~s("status":"failure")
    end

    test "jobs are reliably enqueued desipite network failures" do
      {:ok, redix} = Redix.start_link(redis_url())

      capture_log(fn ->
        {:ok, 1} = Redix.command(redix, ["CLIENT", "KILL", "TYPE", "normal"])

        enqueue_job("OK")

        assert_receive {:processed, "OK"}, 3_000
      end)
    end
  end

  describe "Quieting" do
    test "job processing is paused when quieted" do
      Integration.configure(quiet: true)

      enqueue_job("OK")

      refute_receive {:processed, "OK"}

      Integration.configure(quiet: false)

      assert_receive {:processed, "OK"}
    end
  end

  describe "Resurrection" do
    test "orphaned jobs in backup queues are resurrected" do
      enqueue_job("SLOW")

      assert_receive :started

      :ok = stop_supervised(Integration)
      {:ok, _pid} = start_supervised({Integration, identity: "ident:4321", pool_size: 1})

      assert_receive :started

      conn = Pool.checkout(Integration.Pool)

      with_backoff(fn ->
        assert Introspection.backup_size(conn, "ident:1234", "integration") == 0
        assert Introspection.backup_size(conn, "ident:4321", "integration") == 0
      end)
    end
  end

  describe "Retrying" do
    test "jobs are pruned from the backup queue after running" do
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("PASS")

      assert_receive {:processed, "PASS"}

      assert Introspection.queue_size(conn, "integration") == 0

      with_backoff(fn ->
        assert Introspection.backup_size(conn, @identity, "integration") == 0
      end)
    end

    test "failed jobs are enqueued for retry" do
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("FAIL")

      assert_receive :failed

      with_backoff(fn ->
        assert [job | _] = Introspection.retries(conn)

        assert job.retry_count == 1
        assert job.error_class == "RuntimeError"
        assert job.error_message == "bad stuff happened"
      end)
    end

    test "jobs are moved to the dead set when retries are exhausted" do
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("FAIL", retry: true, retry_count: 25)
      enqueue_job("FAIL", retry: true, retry_count: 25, dead: false)

      assert_receive :failed

      with_backoff(fn ->
        assert Introspection.set_size(conn, "retry") == 0
        assert Introspection.set_size(conn, "dead") == 1
      end)
    end
  end

  describe "Expiring Jobs" do
    test "epxiring jobs are not run past the expiration time" do
      logged =
        capture_log(fn ->
          pid_bin = Worker.pid_to_bin()
          job_a = %{Worker.new([pid_bin, 1]) | expires_in: 1}
          job_b = %{Worker.new([pid_bin, 2]) | expires_in: 5_000}

          Integration.enqueue(job_a)
          Integration.enqueue(job_b)

          assert_receive {:processed, 2}
        end)

      assert logged =~ ~s("reason":"expired","source":"kiq","status":"aborted")
      assert logged =~ ~s("status":"success")
    end
  end

  describe "Unique Jobs" do
    test "unique jobs with the same arguments are only enqueued once" do
      conn = Pool.checkout(Integration.Pool)

      at = Timestamp.unix_in(10)

      {:ok, job_a} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
      {:ok, job_b} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
      {:ok, job_c} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))

      assert job_a.unique_token == job_b.unique_token
      assert job_b.unique_token == job_c.unique_token

      with_backoff(fn ->
        assert Introspection.set_size(conn, "schedule") == 1
        assert Introspection.locked?(conn, job_c)
      end)
    end

    test "successful unique jobs are unlocked after completion" do
      conn = Pool.checkout(Integration.Pool)

      {:ok, job} = enqueue_job("PASS", unique_for: :timer.minutes(1))

      assert job.unique_token
      assert job.unlocks_at

      assert_receive {:processed, _}

      with_backoff(fn ->
        refute Introspection.locked?(conn, job)
      end)
    end

    test "started jobs with :unique_until start are unlocked immediately" do
      conn = Pool.checkout(Integration.Pool)

      {:ok, job} = enqueue_job("FAIL", unique_until: "start", unique_for: :timer.minutes(1))

      assert_receive :failed

      with_backoff(fn ->
        refute Introspection.locked?(conn, job)
      end)
    end
  end

  describe "Stats" do
    test "heartbeat process information is recorded for in-process jobs" do
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("SLOW")

      assert_receive :started

      with_backoff(fn ->
        assert Introspection.alive?(conn, @identity)
      end)

      heartbeat = Introspection.heartbeat(conn, @identity)

      assert %{beat: _beat, busy: _busy, quiet: false} = heartbeat
      assert %{info: %{identity: @identity, queues: ["integration"]}} = heartbeat

      [details] =
        conn
        |> Introspection.workers(@identity)
        |> Map.values()

      assert %{queue: "integration", payload: payload, run_at: _} = details
      assert %{jid: _jid, class: _class, retry: _retry} = payload

      assert_receive :stopped
    end

    test "stats for completed jobs are recorded" do
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("PASS")
      enqueue_job("PASS")
      enqueue_job("FAIL")

      assert_receive :failed

      with_backoff(fn ->
        %{processed: new_proc, failed: new_fail} = Introspection.job_stats(conn)

        assert new_proc >= 2
        assert new_fail >= 1
      end)
    end
  end
end
