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
  end

  describe "encode/1" do
    test "it specifies JSON compatible with sidekiq stats reporting" do
      running = %{"jobid" => %{payload: job()}}

      decoded =
        %{queues: [default: 5, special: 5], running: running}
        |> Heartbeat.new()
        |> Jason.encode!()
        |> Jason.decode!(keys: :atoms)

      assert %{concurrency: 10, hostname: _, identity: _, pid: _} = decoded
      assert %{queues: ["default", "special"], labels: [], tag: ""} = decoded
    end
  end

  describe "add_running/2" do
    test "jobs are added to the running set" do
      job_a = job(pid: make_ref())
      job_b = job(pid: make_ref())

      heartbeat =
        []
        |> Heartbeat.new()
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_b)

      assert heartbeat.busy == 2
      assert map_size(heartbeat.running) == 2
    end
  end

  describe "rem_running/2" do
    test "jobs are removed from the running set" do
      job_a = job(pid: make_ref())
      job_b = job(pid: make_ref())

      heartbeat =
        []
        |> Heartbeat.new()
        |> Heartbeat.add_running(job_a)
        |> Heartbeat.add_running(job_b)
        |> Heartbeat.rem_running(job_a)

      assert heartbeat.busy == 1
      assert map_size(heartbeat.running) == 1
    end
  end
end
