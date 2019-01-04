defmodule Kiq.Queue.SchedulerTest do
  use Kiq.Case, async: true
  use ExUnitProperties

  alias Kiq.Queue.Scheduler

  describe "random_interval/1" do
    property "random intervals are within a percentage of the average" do
      check all average <- integer(10..1000),
                jitter <- integer(2..50) do
        interval = Scheduler.random_interval(average, jitter)

        assert_in_delta interval, average, average * (jitter / 100.0)
      end
    end
  end
end
