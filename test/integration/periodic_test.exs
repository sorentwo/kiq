defmodule Kiq.Integration.PeriodicTest do
  use Kiq.Case

  alias Kiq.Integration
  alias Kiq.Integration.Worker

  defp periodic(value) do
    {"* * * * *", Worker, args: [Worker.pid_to_bin(), value]}
  end

  test "periodic jobs are enqueued on startup" do
    {:ok, _pid} = start_supervised({Integration, periodics: [periodic("OK")]})

    assert_receive {:processed, "OK"}

    Integration.clear()

    :ok = stop_supervised(Integration)
  end

  test "periodic jobs are not enqueued twice within the same minute" do
    {:ok, _pid} = start_supervised({Integration, periodics: [periodic("ONE")]})

    assert_receive {:processed, "ONE"}

    :ok = stop_supervised(Integration)

    {:ok, _pid} = start_supervised({Integration, periodics: [periodic("TWO")]})

    refute_receive {:processed, "TWO"}

    Integration.clear()

    :ok = stop_supervised(Integration)
  end
end
