defmodule Kiq.Queue.SchedulerTest do
  use Kiq.Case, async: true

  alias Kiq.EchoClient
  alias Kiq.Queue.Scheduler

  test "polling triggers descheduling of the set" do
    {:ok, cli} = start_supervised({EchoClient, test_pid: self()})
    {:ok, _} = start_supervised({Scheduler, client: cli, poll_interval: 1, set: "schedule"})

    assert_receive {:deschedule, "schedule"}

    :ok = stop_supervised(Scheduler)
    :ok = stop_supervised(EchoClient)
  end

  describe "random_interval/1" do
    test "generating random intervals that target an average" do
      base_average = 1000

      intervals =
        (fn -> Scheduler.random_interval(base_average) end)
        |> Stream.repeatedly()
        |> Enum.take(100)

      assert Enum.all?(intervals, &Kernel.>=(&1, 500))
      assert Enum.all?(intervals, &Kernel.<=(&1, 1500))

      average = Enum.reduce(intervals, &Kernel.+(&1, &2)) / length(intervals)

      assert_in_delta base_average, average, 100
    end
  end
end
