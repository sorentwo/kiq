defmodule Kiq.Integration.UniqueJobsTest do
  use Kiq.Case

  alias Kiq.Integration
  alias Kiq.Integration.Worker
  alias Kiq.Client.{Introspection, Pool, Queueing}

  @moduletag :capture_log

  setup_all do
    start_supervised!(Integration)

    :ok
  end

  setup do
    :ok = Integration.clear_all()

    {:ok, conn: Pool.checkout(Integration.Pool)}
  end

  test "unique jobs with the same arguments are only enqueued once", %{conn: conn} do
    job = unique_job(1)

    {:ok, job_a} = Integration.enqueue(job, in: 60)
    {:ok, job_b} = Integration.enqueue(job, in: 30)
    {:ok, job_c} = Integration.enqueue(job, in: 20)

    assert job_a.unique_token == job_b.unique_token
    assert job_b.unique_token == job_c.unique_token

    assert Introspection.set_size(conn, "schedule") == 1
    assert Queueing.locked?(conn, job_c)
  end

  test "successful unique jobs are unlocked after completion", %{conn: conn} do
    job = unique_job(2)

    {:ok, job} = Integration.enqueue(job)

    assert job.unique_token
    assert job.unlocks_at

    assert Queueing.locked?(conn, job)

    assert_receive {:processed, 2}, 1_500

    refute_locked(conn, job)
  end

  test "started jobs with :unique_until start are unlocked immediately", %{conn: conn} do
    job = %{unique_job("FAILING_JOB") | unique_until: "start"}

    {:ok, job} = Integration.enqueue(job)

    assert Queueing.locked?(conn, job)

    assert_receive {:failed, "FAILING_JOB"}, 1_500

    refute_locked(conn, job)
  end

  defp unique_job(value) do
    %{Worker.new([Worker.pid_to_bin(), value]) | unique_for: :timer.minutes(1)}
  end

  defp refute_locked(conn, job), do: refute_locked(conn, job, 0, 20)

  defp refute_locked(_conn, job, limit, limit) do
    flunk "Job with #{job.jid} is still locked"
  end

  defp refute_locked(conn, job, retry, limit) do
    if Queueing.locked?(conn, job) do
      Process.sleep(50)

      refute_locked(conn, job, retry + 1, limit)
    end
  end
end
