defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Heartbeat, Job}
  alias Kiq.Client.{Cleanup, Introspection, Pool, Queueing, Stats}

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

  @spec retry(client(), Job.t()) :: {:ok, Job.t()}
  def retry(client, %Job{retry: retry, retry_count: count} = job)
      when is_integer(retry) or (retry == true and count > 0) do
    GenServer.call(client, {:retry, job})
  end

  @spec dequeue(client(), queue(), pos_integer()) :: list(iodata())
  def dequeue(_client, _queue, 0), do: []

  def dequeue(client, queue, count) when is_binary(queue) and is_integer(count) do
    GenServer.call(client, {:dequeue, queue, count})
  end

  @spec deschedule(client(), set()) :: :ok
  def deschedule(client, set) when is_binary(set) do
    GenServer.call(client, {:deschedule, set})
  end

  @spec resurrect(client(), queue()) :: :ok
  def resurrect(client, queue) when is_binary(queue) do
    GenServer.call(client, {:resurrect, queue})
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

  @spec remove_backup(client(), Job.t()) :: :ok
  def remove_backup(client, %Job{queue: queue} = job) when is_binary(queue) do
    GenServer.call(client, {:remove_backup, job})
  end

  @spec unlock_job(client(), Job.t()) :: :ok
  def unlock_job(client, %Job{} = job) do
    GenServer.call(client, {:unlock_job, job})
  end

  ## Stats

  @spec record_heart(client(), Heartbeat.t()) :: :ok
  def record_heart(client, %Heartbeat{} = heartbeat) do
    GenServer.call(client, {:record_heart, heartbeat})
  end

  @spec record_stats(client(), stat_report()) :: :ok
  def record_stats(client, stats) when is_list(stats) do
    GenServer.call(client, {:record_stats, stats})
  end

  @spec remove_heart(client(), Heartbeat.t()) :: :ok
  def remove_heart(client, %Heartbeat{} = heartbeat) do
    GenServer.call(client, {:remove_heart, heartbeat})
  end

  # Server

  @impl GenServer
  def init(config: %Config{pool_name: pool_name}) do
    {:ok, %State{pool: pool_name}}
  end

  ## Enqueuing | Dequeuing

  @impl GenServer
  def handle_call({:enqueue, job}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.enqueue(conn(pool), job), state}
  end

  def handle_call({:retry, job}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.retry(conn(pool), job), state}
  end

  def handle_call({:dequeue, queue, count}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.dequeue(conn(pool), queue, count), state}
  end

  def handle_call({:deschedule, set}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.deschedule(conn(pool), set), state}
  end

  def handle_call({:resurrect, queue}, _from, %State{pool: pool} = state) do
    {:reply, Queueing.resurrect(conn(pool), queue), state}
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

  def handle_call({:remove_backup, job}, _from, %State{pool: pool} = state) do
    {:reply, Cleanup.remove_backup(conn(pool), job), state}
  end

  def handle_call({:unlock_job, job}, _from, %State{pool: pool} = state) do
    {:reply, Cleanup.unlock_job(conn(pool), job), state}
  end

  ## Stats

  def handle_call({:record_heart, heartbeat}, _from, %State{pool: pool} = state) do
    {:reply, Stats.record_heart(conn(pool), heartbeat), state}
  end

  def handle_call({:record_stats, stats}, _from, %State{pool: pool} = state) do
    {:reply, Stats.record_stats(conn(pool), stats), state}
  end

  def handle_call({:remove_heart, heartbeat}, _from, %State{pool: pool} = state) do
    {:reply, Stats.remove_heart(conn(pool), heartbeat), state}
  end

  defp conn(pool), do: Pool.checkout(pool)
end
