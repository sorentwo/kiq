defmodule Kiq.Integration.RetryingJobsTest do
  use Kiq.Case

  alias Kiq.Integration
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

  test "jobs are pruned from the backup queue after running", %{conn: conn} do
    enqueue_job("PASS")

    assert_receive {:processed, "PASS"}

    assert Introspection.queue_size(conn, "integration") == 0

    with_backoff(fn ->
      assert Introspection.backup_size(conn, "integration") == 0
    end)
  end

  test "failed jobs are enqueued for retry", %{conn: conn} do
    enqueue_job("FAIL")

    assert_receive :failed

    with_backoff(fn ->
      assert [job] = Introspection.retries(conn)

      assert job.retry_count == 1
      assert job.error_class == "RuntimeError"
      assert job.error_message == "bad stuff happened"
    end)
  end

  test "jobs are not enqueued when retries are exhausted", %{conn: conn} do
    enqueue_job("FAIL", retry: true, retry_count: 25)

    assert_receive :failed

    assert Introspection.set_size(conn, "retry") == 0
  end
end
