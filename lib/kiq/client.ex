defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Pool, Job}
  alias Kiq.Client.{Cleanup, Introspection, Queueing}

  @type client :: GenServer.server()
  @type queue :: binary()
  @type options :: [config: Config.t(), name: GenServer.name()]
  @type set :: binary()
  @type stat_report :: [success: integer(), failure: integer()]

  defmodule State do
    @moduledoc false

    defstruct pool: nil
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec enqueue(client(), Job.t()) :: {:ok, Job.t()}
  def enqueue(client, %Job{queue: queue} = job) when is_binary(queue) do
    GenServer.call(client, {:enqueue, job})
  end

  ## Introspection

  @spec jobs(client(), queue()) :: list(Job.t())
  def jobs(client, queue) when is_binary(queue) do
    GenServer.call(client, {:jobs, queue})
  end

  @spec queue_size(client(), queue()) :: pos_integer()
  def queue_size(client, queue) when is_binary(queue) do
    GenServer.call(client, {:queue_size, queue})
  end

  @spec set_size(client(), set()) :: pos_integer()
  def set_size(client, set) when is_binary(set) do
    GenServer.call(client, {:set_size, set})
  end

  ## Clearing & Removal

  @spec clear_all(client()) :: :ok
  def clear_all(client) do
    GenServer.call(client, :clear_all)
  end

  # Server

  @impl GenServer
  def init(config: %Config{pool_name: pool_name}) do
    {:ok, %State{pool: pool_name}}
  end

  @impl GenServer
  def handle_call({:enqueue, job}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.enqueue(conn(pool), job), state}
  end

  ## Introspection

  def handle_call({:jobs, queue}, _from, %State{pool: pool} = state) do
    {:reply, Introspection.jobs(conn(pool), queue), state}
  end

  def handle_call({:queue_size, queue}, _from, %State{pool: pool} = state) do
    {:reply, Introspection.queue_size(conn(pool), queue), state}
  end

  def handle_call({:set_size, set}, _from, %State{pool: pool} = state) do
    {:reply, Introspection.set_size(conn(pool), set), state}
  end

  ## Clearing & Removal

  def handle_call(:clear_all, _from, %State{pool: pool} = state) do
    {:reply, Cleanup.clear_all(conn(pool)), state}
  end

  defp conn(pool), do: Pool.checkout(pool)
end
