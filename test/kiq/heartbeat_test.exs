defmodule Kiq.HeartbeatTest do
  use Kiq.Case, async: true

  alias Kiq.Heartbeat

  describe "new/1" do
    test "a complete struct is generated using provided values" do
      heartbeat = Heartbeat.new(%{queues: [default: 10, heavy: 2], quiet: true})

      assert heartbeat.concurrency == 12
      assert heartbeat.hostname
      assert heartbeat.identity
      assert heartbeat.pid =~ ~r/<\d\.\d+\.\d>/
      assert heartbeat.quiet
      assert is_float(heartbeat.started_at)
    end

    test "the DYNO environment variable is used for hostname when present" do
      System.put_env("DYNO", "worker-123")

      assert %Heartbeat{hostname: "worker-123"} = Heartbeat.new(%{queues: []})
    after
      System.delete_env("DYNO")
    end
  end

  describe "encode/1" do
    test "it encodes JSON compatible with sidekiq stats reporting" do
      running = %{"jobid" => %{payload: job()}}

      decoded =
        %{queues: [default: 5, special: 5], running: running}
        |> Heartbeat.new()
        |> Heartbeat.encode()
        |> Jason.decode!(keys: :atoms)

      assert %{concurrency: 10, hostname: _, identity: _, pid: _} = decoded
      assert %{queues: ["default", "special"], labels: [], tag: ""} = decoded
    end
  end

  describe "add_running/2" do
    test "jobs are added to the running set" do
      job_a = job()
      job_b = job()

      heartbeat =
        []
        |> Heartbeat.new()
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_b)

      assert heartbeat.busy == 2
    end
  end

  describe "rem_running/2" do
    test "jobs are removed from the running set" do
      job_a = job()
      job_b = job()

      heartbeat =
        []
        |> Heartbeat.new()
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_b)
        |> Heartbeat.rem_running(job_a)

      assert heartbeat.busy == 1
    end
  end
end
