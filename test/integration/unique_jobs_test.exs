defmodule Kiq.Integration.UniqueJobsTest do
  use Kiq.Case

  alias Kiq.{Integration, Timestamp}
  alias Kiq.Client.{Introspection, Pool}

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
    at = Timestamp.unix_in(1)

    {:ok, job_a} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
    {:ok, job_b} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))
    {:ok, job_c} = enqueue_job("PASS", at: at, unique_for: :timer.minutes(1))

    assert job_a.unique_token == job_b.unique_token
    assert job_b.unique_token == job_c.unique_token

    assert Introspection.set_size(conn, "schedule") == 1
    assert Introspection.locked?(conn, job_c)
  end

  test "successful unique jobs are unlocked after completion", %{conn: conn} do
    {:ok, job} = enqueue_job("PASS", unique_for: :timer.minutes(1))

    assert job.unique_token
    assert job.unlocks_at

    assert Introspection.locked?(conn, job)

    assert_receive {:processed, _}

    with_backoff(fn ->
      refute Introspection.locked?(conn, job)
    end)
  end

  test "started jobs with :unique_until start are unlocked immediately", %{conn: conn} do
    {:ok, job} = enqueue_job("FAIL", unique_until: "start", unique_for: :timer.minutes(1))

    assert Introspection.locked?(conn, job)

    assert_receive :failed

    with_backoff(fn ->
      refute Introspection.locked?(conn, job)
    end)
  end
end
