defmodule Kiq.Integration.ExpiringJobsTest do
  use Kiq.Case

  import ExUnit.CaptureLog

  alias Kiq.Integration
  alias Kiq.Integration.Worker

  setup do
    start_supervised!(Integration)

    :ok = Integration.clear_all()
  end

  test "epxiring jobs are not run past the expiration time" do
    pid_bin = Worker.pid_to_bin()
    job_a = %{Worker.new([pid_bin, 1]) | expires_in: 1}
    job_b = %{Worker.new([pid_bin, 2]) | expires_in: 5_000}

    logged =
      capture_log([colors: [enabled: false]], fn ->
        Integration.enqueue(job_a)
        Integration.enqueue(job_b)

        assert_receive {:processed, 2}
      end)

    assert logged =~
             ~s("jid":"#{job_a.jid}","queue":"integration","reason":"expired","status":"aborted")

    assert logged =~ ~s("jid":"#{job_b.jid}","queue":"integration","status":"success")
  end
end
