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

  @log_opts [colors: [enabled: false]]

  setup do
    start_supervised!(Integration)

    :ok = Integration.clear_all()
  end

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_log(@log_opts, fn ->
        for index <- 1..5 do
          [pid_bin(), index]
          |> IntegrationWorker.new()
          |> Integration.enqueue()

          assert_receive {:processed, ^index}, 2_000
        end
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")
  end

  test "successful unique jobs are unlocked after completion" do
    job = %{IntegrationWorker.new([pid_bin(), 1]) | unique_for: :timer.minutes(1)}

    capture_log(@log_opts, fn ->
      Integration.enqueue(job)

      assert_receive {:processed, 1}, 1_000

      # Guarantee that the unlocker has enough time to run
      Process.sleep(1_010)

      Integration.enqueue(job)

      assert_receive {:processed, 1}, 2_000
    end)
  end

  test "epxiring jobs are not run past the expiration time" do
    job_a = %{IntegrationWorker.new([pid_bin(), 1]) | expires_in: 1}
    job_b = %{IntegrationWorker.new([pid_bin(), 2]) | expires_in: 5_000}

    logged =
      capture_log(@log_opts, fn ->
        Integration.enqueue(job_a)
        Integration.enqueue(job_b)

        assert_receive {:processed, 2}, 2_000
      end)

    assert logged =~ ~s("reason":"expired","status":"aborted")
  end

  defp pid_bin do
    self()
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end
end
