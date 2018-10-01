defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  import ExUnit.CaptureLog

  alias Kiq.Integration
  alias Kiq.Integration.Worker

  setup do
    start_supervised!(Integration)

    :ok = Integration.clear_all()
  end

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5 do
          [Worker.pid_to_bin(), index]
          |> Worker.new()
          |> Integration.enqueue()

          assert_receive {:processed, ^index}, 2_000
        end
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")
  end
end
