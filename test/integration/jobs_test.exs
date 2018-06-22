defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  import ExUnit.CaptureLog

  @table :jobs_test

  defmodule IntegrationWorker do
    use Kiq.Worker, queue: "integration"

    def perform([value]) do
      :ets.insert(:jobs_test, {value})
    end
  end

  setup do
    :ets.new(@table, [:public, :named_table])

    config = Kiq.Config.new(queues: [integration: 2], client_opts: [redis_url: redis_url()])

    start_supervised!({Kiq.Supervisor, config: config})

    :ok
  end

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5, do: IntegrationWorker.perform_async(Kiq.Client, [index])

        assert_values([1, 2, 3, 4, 5])
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")

    :ok = stop_supervised(Kiq.Supervisor)
  end

  test "scheduling and executing jobs successfully" do
    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5, do: IntegrationWorker.perform_in(Kiq.Client, 1, [index])

        assert_values([1, 2, 3, 4, 5], retry: 50)
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")

    :ok = stop_supervised(Kiq.Supervisor)
  end

  defp assert_values(values, opts \\ []) when is_list(opts) do
    retry = Keyword.get(opts, :retry, 20)
    sleep = Keyword.get(opts, :sleep, 100)

    assert_values(values, 0, retry, sleep)
  end

  defp assert_values(_values, count, count, _sleep) do
    flunk("jobs were never processed")
  end

  defp assert_values(values, count, retry, sleep) do
    results =
      @table
      |> :ets.tab2list()
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    case results do
      [_head | _tail] ->
        assert values == results

      _ ->
        Process.sleep(sleep)
        assert_values(values, count + 1, retry, sleep)
    end
  end
end
