defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  alias Kiq.Integration
  alias Kiq.Integration.Worker

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_integration(fn ->
        for index <- 1..5 do
          [Worker.pid_to_bin(), index]
          |> Worker.new()
          |> Integration.enqueue()

          assert_receive {:processed, ^index}
        end
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")
  end

  # Sandbox testing
  # 3. jobs are enqueued
  # 4. if a process dies before flushing it is retained
  # 5. if there is a redis error the jobs are retained until the next flush cycle
end
