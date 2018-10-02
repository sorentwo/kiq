defmodule Kiq.Pool.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.Config
  alias Kiq.Pool.Supervisor, as: PoolSupervisor

  describe "start_link/1" do
    test "the specified number of redis connections are started" do
      config = %Config{client_opts: [redis_url: redis_url()], pool_size: 2}

      {:ok, sup} = start_supervised({PoolSupervisor, config: config})

      [_, _] = Supervisor.which_children(sup)

      :ok = stop_supervised(PoolSupervisor)
    end
  end
end
