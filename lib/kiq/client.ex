defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Pool, Job}
  alias Kiq.Client.{Cleanup, Queueing}

  @type client :: GenServer.server()
  @type options :: [config: Config.t(), name: GenServer.name()]
  @type scoping :: :sandbox | :shared

  defmodule State do
    @moduledoc false

    defstruct [:flush_interval, :pool, :table]
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # @spec flush(client()) :: :ok

  @spec store(client(), Job.t()) :: {:ok, Job.t()}
  def store(client, %Job{queue: queue} = job) when is_binary(queue) do
    GenServer.call(client, {:store, job})
  end

  @spec fetch(client(), scoping()) :: list(Job.t())
  def fetch(client, scoping \\ :sandbox) when scoping in [:sandbox, :shared] do
    GenServer.call(client, {:fetch, scoping})
  end

  @spec clear(client()) :: :ok
  def clear(client) do
    GenServer.call(client, :clear)
  end

  # Server

  @impl GenServer
  def init(config: %Config{flush_interval: interval, pool_name: pool}) do
    table = :ets.new(:jobs, [:duplicate_bag, :compressed])
    state = %State{flush_interval: interval, pool: pool, table: table}

    schedule_flush(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{table: table} = state) do
    :ets.delete(table, pid)

    {:noreply, state}
  end

  def handle_info(:flush, state) do
    state
    |> perform_flush()
    |> schedule_flush()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:clear, _from, %State{pool: pool, table: table} = state) do
    true = :ets.delete_all_objects(table)

    :ok =
      pool
      |> Pool.checkout()
      |> Cleanup.clear()

    {:reply, :ok, state}
  end

  def handle_call({:store, job}, {pid, _tag}, %State{table: table} = state) do
    table
    |> maybe_monitor(pid)
    |> :ets.insert({pid, job})

    {:reply, {:ok, job}, state}
  end

  def handle_call({:fetch, scoping}, {pid, _tag}, %State{table: table} = state) do
    pid_match = if scoping == :sandbox, do: pid, else: :_
    jobs = :ets.select(table, [{{pid_match, :"$1"}, [], [:"$1"]}])

    {:reply, jobs, state}
  end

  # Helpers

  defp schedule_flush(%State{flush_interval: interval} = state) do
    Process.send_after(self(), :flush, interval)

    state
  end

  defp perform_flush(%State{pool: pool, table: table} = state) do
    conn = Pool.checkout(pool)

    table
    |> :ets.select([{{:_, :"$1"}, [], [:"$1"]}])
    |> Enum.map(&Queueing.enqueue(conn, &1))

    true = :ets.delete_all_objects(table)

    state
  end

  defp maybe_monitor(table, pid, limit \\ 1) do
    case :ets.select(table, [{{pid, :_}, [], [true]}], limit) do
      {[true], _cont} -> true
      _ -> Process.monitor(pid)
    end

    table
  end
end
