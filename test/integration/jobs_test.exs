defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  import ExUnit.CaptureLog

  defmodule Integration do
    use Kiq, queues: [integration: 3]

    @impl Kiq
    def init(_reason, opts) do
      client_opts = [redis_url: Kiq.Case.redis_url()]

      {:ok, Keyword.put(opts, :client_opts, client_opts)}
    end
  end

  defmodule IntegrationWorker do
    use Kiq.Worker, queue: "integration"

    def perform([pid_bin, value]) do
      pid =
        pid_bin
        |> Base.decode64!()
        |> :erlang.binary_to_term()

      send(pid, {:processed, value})
    end
  end

  test "enqueuing and executing jobs successfully" do
    start_supervised!(Integration)

    :ok = Integration.clear_all()

    pid_bin =
      self()
      |> :erlang.term_to_binary()
      |> Base.encode64()

    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5 do
          [pid_bin, index]
          |> IntegrationWorker.new()
          |> Integration.enqueue()

          assert_receive {:processed, ^index}, 2_000
        end
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")
  end
end
