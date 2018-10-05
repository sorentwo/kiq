defmodule Kiq.Integration.RetryingJobsTest do
  use Kiq.Case

  alias Kiq.{Integration, Pool}
  alias Kiq.Client.Introspection

  test "jobs are pruned from the backup queue after running" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("PASS")

      assert_receive {:processed, "PASS"}

      assert Introspection.queue_size(conn, "integration") == 0

      with_backoff(fn ->
        assert Introspection.backup_size(conn, "integration") == 0
      end)
    end)
  end

  test "failed jobs are enqueued for retry" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("FAIL")

      assert_receive :failed

      with_backoff(fn ->
        assert [job] = Introspection.retries(conn)

        assert job.retry_count == 1
        assert job.error_class == "RuntimeError"
        assert job.error_message == "bad stuff happened"
      end)
    end)
  end

  test "jobs are not enqueued when retries are exhausted" do
    capture_integration(fn ->
      conn = Pool.checkout(Integration.Pool)

      enqueue_job("FAIL", retry: true, retry_count: 25)

      assert_receive :failed

      assert Introspection.set_size(conn, "retry") == 0
    end)
  end
end
