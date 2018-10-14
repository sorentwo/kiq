defmodule Kiq.Integration.UniqueJobsTest do
  use Kiq.Case

  alias Kiq.{Integration, Pool, Timestamp}
  alias Kiq.Client.Introspection

  test "unique jobs with the same arguments are only enqueued once" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      at = Timestamp.unix_in(1)

      {:ok, job_a} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
      {:ok, job_b} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
      {:ok, job_c} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))

      assert job_a.unique_token == job_b.unique_token
      assert job_b.unique_token == job_c.unique_token

      with_backoff(fn ->
        assert Introspection.set_size(conn, "schedule") == 1
        assert Introspection.locked?(conn, job_c)
      end)
    end)
  end

  test "successful unique jobs are unlocked after completion" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      {:ok, job} = enqueue_job("PASS", unique_for: :timer.minutes(1))

      assert job.unique_token
      assert job.unlocks_at

      with_backoff(fn ->
        assert Introspection.locked?(conn, job)
      end)

      assert_receive {:processed, _}

      with_backoff(fn ->
        refute Introspection.locked?(conn, job)
      end)
    end)
  end

  test "started jobs with :unique_until start are unlocked immediately" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      {:ok, job} = enqueue_job("FAIL", unique_until: "start", unique_for: :timer.minutes(1))

      with_backoff(fn ->
        assert Introspection.locked?(conn, job)
      end)

      assert_receive :failed

      with_backoff(fn ->
        refute Introspection.locked?(conn, job)
      end)
    end)
  end
end
