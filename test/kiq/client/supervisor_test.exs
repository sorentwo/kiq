defmodule Kiq.Client.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.Config
  alias Kiq.Client.Supervisor, as: ClientSupervisor

  describe "start_link/1" do
    test "the specified number of redis connections are started" do
      config = %Config{client_opts: [redis_url: redis_url(), pool_size: 2]}

      {:ok, sup} = start_supervised({ClientSupervisor, config: config})

      [_, _] = Supervisor.which_children(sup)

      :ok = stop_supervised(ClientSupervisor)
    end
  end
end
