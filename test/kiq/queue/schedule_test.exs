defmodule Kiq.Queue.SchedulerTest do
  use Kiq.Case, async: true

  alias Kiq.Queue.Scheduler

  defmodule FakeClient do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:ok, opts}
    end

    def handle_call(message, _from, state) do
      send state[:test_pid], message

      {:reply, :ok, state}
    end
  end

  test "polling triggers descheduling of the set" do
    {:ok, cli} = start_supervised({FakeClient, test_pid: self()})
    {:ok, _} = start_supervised({Scheduler, client: cli, init_interval: 1, set: "schedule"})

    assert_receive {:deschedule, "schedule"}

    :ok = stop_supervised(Scheduler)
    :ok = stop_supervised(FakeClient)
  end

  describe "random_interval/1" do
    test "generating random intervals that target an average" do
      base_average = 1000

      intervals =
        (fn -> Scheduler.random_interval(base_average) end)
        |> Stream.repeatedly()
        |> Enum.take(100)

      refute Enum.any?(intervals, &Kernel.==(&1, base_average))
      assert Enum.all?(intervals, &Kernel.>=(&1, 500))
      assert Enum.all?(intervals, &Kernel.<=(&1, 1500))

      average = Enum.reduce(intervals, &Kernel.+(&1, &2)) / length(intervals)

      assert_in_delta base_average, average, 100
    end
  end
end
