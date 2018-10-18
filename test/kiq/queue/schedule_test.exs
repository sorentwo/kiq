defmodule Kiq.Queue.SchedulerTest do
  use Kiq.Case, async: true

  alias Kiq.Queue.Scheduler

  describe "random_interval/1" do
    test "generating random intervals that target an average" do
      base_average = 1000

      intervals =
        fn -> Scheduler.random_interval(base_average) end
        |> Stream.repeatedly()
        |> Enum.take(100)

      assert Enum.all?(intervals, &Kernel.>=(&1, 500))
      assert Enum.all?(intervals, &Kernel.<=(&1, 1500))

      average = Enum.reduce(intervals, &Kernel.+(&1, &2)) / length(intervals)

      assert_in_delta base_average, average, 100
    end
  end
end
