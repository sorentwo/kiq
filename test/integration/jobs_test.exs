defmodule Kiq.Integration.JobsTest do
  use Kiq.Case

  import ExUnit.CaptureLog

  @table :jobs_test

  defmodule Integration do
    use Kiq, queues: [integration: 2]

    @impl Kiq
    def init(_reason, opts) do
      client_opts = [redis_url: Kiq.Case.redis_url()]

      {:ok, Keyword.put(opts, :client_opts, client_opts)}
    end
  end

  defmodule IntegrationWorker do
    use Kiq.Worker, queue: "integration"

    def perform([value]) do
      :ets.insert(:jobs_test, {value})
    end
  end

  setup do
    :ets.new(@table, [:public, :named_table])

    start_supervised!(Integration)

    :ok
  end

  test "enqueuing and executing jobs successfully" do
    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5 do
          [index]
          |> IntegrationWorker.new()
          |> Integration.enqueue()
        end

        assert_values([1, 2, 3, 4, 5])
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")

    :ok = stop_supervised(Integration)
  end

  test "scheduling and executing jobs successfully" do
    logged =
      capture_log([colors: [enabled: false]], fn ->
        for index <- 1..5 do
          [index]
          |> IntegrationWorker.new()
          |> Integration.enqueue(in: 1)
        end

        assert_values([1, 2, 3, 4, 5], retry: 50)
      end)

    assert logged =~ ~s("status":"started")
    assert logged =~ ~s("status":"success")
    refute logged =~ ~s("status":"failure")

    :ok = stop_supervised(Integration)
  end

  defp assert_values(values, opts \\ []) when is_list(opts) do
    retry = Keyword.get(opts, :retry, 10)
    sleep = Keyword.get(opts, :sleep, 200)

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
