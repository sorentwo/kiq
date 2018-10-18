defmodule Kiq.Pool.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.Pool.Supervisor, as: PoolSupervisor

  describe "start_link/1" do
    test "the specified number of redis connections are started" do
      config = config(pool_size: 2)

      {:ok, sup} = start_supervised({PoolSupervisor, config: config})

      [_, _] = Supervisor.which_children(sup)

      :ok = stop_supervised(PoolSupervisor)
    end
  end
end
