defmodule Kiq.SupervisorTest do
  use Kiq.Case

  alias Kiq.Config
  alias Kiq.Supervisor, as: KiqSup

  describe "start_link/1" do
    test "named processes are started based on provided configuration" do
      config =
        Config.new(
          client_opts: [redis_url: redis_url()],
          schedulers: ["retry"],
          queues: [default: 2, priority: 2]
        )

      {:ok, sup} = start_supervised({KiqSup, config: config})

      children = for {name, _pid, _type, _id} <- Supervisor.which_children(sup), do: name

      assert Kiq.Client in children
      assert Kiq.Reporter.Supervisor in children
      assert Kiq.Queue.Default in children
      assert Kiq.Queue.Priority in children
      assert Kiq.Scheduler.Retry in children

      :ok = stop_supervised(KiqSup)
    end

    test "only the client is started when :server? is false" do
      config = Config.new(client_opts: [redis_url: redis_url()], server?: false)

      {:ok, sup} = start_supervised({KiqSup, config: config})

      children = for {_, _pid, _type, [module]} <- Supervisor.which_children(sup), do: module

      assert Kiq.Client in children
      refute Kiq.Reporter.Supervisor in children
      refute Kiq.Queue.Scheduler in children
      refute Kiq.Queue.Supervisor in children

      :ok = stop_supervised(KiqSup)
    end
  end
end
