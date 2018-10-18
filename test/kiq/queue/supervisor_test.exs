defmodule Kiq.Queue.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.FakeClient
  alias Kiq.Queue.Supervisor, as: QueueSupervisor

  defmodule FakeClient do
    use GenServer

    def start_link(opts) do
      {name, opts} = Keyword.pop(opts, :name)

      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def init(opts) do
      {:ok, opts}
    end

    def handle_call({:queue_size, _queue}, _from, state) do
      {:reply, 0, state}
    end

    def handle_call({:dequeue, _queue, _size}, _from, state) do
      {:reply, [], state}
    end
  end

  describe "start_link/1" do
    test "producer and consumer children are managed for the queue" do
      config = config(client_name: Fake, reporter_name: Kiq.Rep)

      {:ok, _cl} = start_supervised({FakeClient, name: Fake})
      {:ok, sup} = start_supervised({QueueSupervisor, [config: config, queue: "sup", limit: 10]})

      [consumer, producer] = Supervisor.which_children(sup)

      assert {Kiq.Queue.Consumer, _pid, :supervisor, _} = consumer
      assert {Kiq.Queue.Producer, _pid, :worker, _} = producer
      assert Process.whereis(:"Elixir.Kiq.Sup.Producer")
      assert Process.whereis(:"Elixir.Kiq.Sup.Consumer")

      :ok = stop_supervised(FakeClient)
      :ok = stop_supervised(QueueSupervisor)
    end
  end
end
