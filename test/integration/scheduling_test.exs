defmodule Kiq.Integration.SchedulingTest do
  use Kiq.Case

  alias Kiq.Integration

  test "scheduled jobs are descheduled and executed" do
    {:ok, _pid} = start_supervised({Integration, fetch_interval: 10})

    Integration.clear()

    enqueue_job("A", at: unix_in(11, :millisecond))
    enqueue_job("B", at: unix_in(5, :millisecond))
    enqueue_job("C", at: unix_in(25, :millisecond))

    assert_receive {:processed, "C"}
    assert_receive {:processed, "A"}
    assert_receive {:processed, "B"}

    :ok = stop_supervised(Integration)
  end
end
