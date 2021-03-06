defmodule Kiq.PoolTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, Pool}

  defmodule DummyWorker do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, nil, opts)
    end

    def init(_opts), do: {:ok, nil}
  end

  describe "checkout/1" do
    test "a random connection pid is returned" do
      config = %Config{pool_size: 2, pool_name: PoolTest.Pool}
      name_a = Pool.worker_name(config.pool_name, 0)
      name_b = Pool.worker_name(config.pool_name, 1)

      {:ok, ppid} = start_supervised({Pool, config: config})
      {:ok, wpid_a} = start_supervised({DummyWorker, name: name_a}, id: name_a)
      {:ok, wpid_b} = start_supervised({DummyWorker, name: name_b}, id: name_b)

      assert Pool.checkout(ppid) in [wpid_a, wpid_b]

      :ok = stop_supervised(name_a)
      :ok = stop_supervised(name_b)

      refute Pool.checkout(ppid)

      :ok = stop_supervised(Pool)
    end
  end
end
