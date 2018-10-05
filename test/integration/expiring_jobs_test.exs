defmodule Kiq.Integration.ExpiringJobsTest do
  use Kiq.Case

  alias Kiq.Integration
  alias Kiq.Integration.Worker

  test "epxiring jobs are not run past the expiration time" do
    logged =
      capture_integration(fn ->
        pid_bin = Worker.pid_to_bin()
        job_a = %{Worker.new([pid_bin, 1]) | expires_in: 1}
        job_b = %{Worker.new([pid_bin, 2]) | expires_in: 5_000}

        Integration.enqueue(job_a)
        Integration.enqueue(job_b)

        assert_receive {:processed, 2}
      end)

    assert logged =~ ~s("queue":"integration","reason":"expired","status":"aborted")
    assert logged =~ ~s("queue":"integration","status":"success")
  end
end
