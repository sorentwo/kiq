defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_integration(fn ->
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
    capture_integration([pool_size: 1], fn ->
      {:ok, redix} = Redix.start_link(redis_url())
      {:ok, 1} = Redix.command(redix, ["CLIENT", "KILL", "TYPE", "normal"])

      enqueue_job("OK")

      assert_receive {:processed, "OK"}
    end)
  end
end
