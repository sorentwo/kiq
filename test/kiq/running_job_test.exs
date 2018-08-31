defmodule Kiq.RunningJobTest do
  use Kiq.Case, async: true

  alias Kiq.RunningJob

  describe "new/1" do
    test "job structs are converted to an encoded heartbeat compliant format" do
      job = job(queue: "special", pid: make_ref(), args: [1, 2])

      %RunningJob{key: key, encoded: encoded} = RunningJob.new(job)

      assert is_binary(key)
      assert is_binary(encoded)

      decoded = Jason.decode!(encoded, keys: :atoms)

      assert %{queue: queue, payload: payload, run_at: run_at} = decoded
      assert queue == job.queue
      assert payload.args == job.args
      assert run_at
    end
  end
end
