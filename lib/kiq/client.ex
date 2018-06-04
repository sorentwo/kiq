defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Job, Timestamp}

  @type client :: GenServer.t()
  @type queue :: binary() | atom()
  @type set :: binary() | atom()

  defmodule State do
    @moduledoc false

    @enforce_keys [:conn]
    defstruct conn: nil, retry_set: "retry", schedule_set: "schedule"
  end

  @doc false
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec enqueue(client(), Job.t()) :: Job.t()
  # def enqueue(client, %Job{retry: true, retry_count: count} = job) when count > 0 do
  #   GenServer.call(client, {:enqueue_at, job, @retry_set})
  # end

  def enqueue(client, %Job{at: at} = job) when is_float(at) do
    GenServer.call(client, {:enqueue_at, job})
  end

  def enqueue(client, %Job{queue: queue} = job) when is_binary(queue) or is_atom(queue) do
    GenServer.call(client, {:enqueue, job})
  end

  # Introspection

  @doc false
  @spec queue_size(client(), queue()) :: pos_integer()
  def queue_size(client, queue) when is_binary(queue) or is_atom(queue) do
    GenServer.call(client, {:queue_size, queue})
  end

  @doc false
  @spec set_size(client(), set()) :: pos_integer()
  def set_size(client, set) when is_binary(set) or is_atom(set) do
    GenServer.call(client, {:set_size, set})
  end

  # Clearing & Removal

  @doc false
  @spec clear_queue(client(), queue()) :: :ok
  def clear_queue(client, queue) when is_binary(queue) or is_atom(queue) do
    GenServer.call(client, {:clear, [queue_name(queue), backup_name(queue)]})
  end

  @doc false
  @spec clear_set(client(), queue()) :: :ok
  def clear_set(client, set) when is_binary(set) or is_atom(set) do
    GenServer.call(client, {:clear, [set]})
  end

  @doc false
  @spec remove_backup(client(), Job.t()) :: :ok
  def remove_backup(client, %Job{queue: queue} = job) when is_atom(queue) or is_binary(queue) do
    GenServer.call(client, {:remove_backup, job})
  end

  # Server

  @impl GenServer
  def init(redis_url: redis_url) do
    {:ok, conn} = Redix.start_link(redis_url)

    {:ok, %State{conn: conn}}
  end

  ## Enqueuing | Dequeuing

  @impl GenServer
  def handle_call({:enqueue, job}, _from, %State{conn: conn} = state) do
    {:reply, push_job(conn, job), state}
  end

  def handle_call({:enqueue_at, job}, _from, %State{conn: conn, schedule_set: set} = state) do
    score = Timestamp.to_score(job.at)

    {:ok, _result} = Redix.command(conn, ["ZADD", set, score, Job.encode(job)])

    {:reply, {:ok, job}, state}
  end

  ## Introspection

  def handle_call({:queue_size, queue}, _from, %State{conn: conn} = state) do
    {:ok, count} = Redix.command(conn, ["LLEN", queue_name(queue)])

    {:reply, count, state}
  end

  def handle_call({:set_size, set}, _from, %State{conn: conn} = state) do
    {:ok, count} = Redix.command(conn, ["ZCOUNT", set, "-inf", "+inf"])

    {:reply, count, state}
  end

  ## Clearing & Removal

  def handle_call({:clear, keys}, _from, %State{conn: conn} = state) do
    {:ok, _result} = Redix.command(conn, ["DEL" | keys])

    {:reply, :ok, state}
  end

  def handle_call({:remove_backup, job}, _from, %State{conn: conn} = state) do
    {:ok, _result} = Redix.command(conn, ["LREM", backup_name(job.queue), "0", Job.encode(job)])

    {:reply, :ok, state}
  end

  # Helpers

  defp queue_name(queue), do: "queue:#{queue}"

  defp backup_name(queue), do: "queue:#{queue}:backup"

  defp push_job(conn, %Job{queue: queue} = job) do
    commands = [
      ["SADD", "queues", queue],
      ["LPUSH", queue_name(queue), Job.encode(job)]
    ]

    {:ok, _result} = Redix.pipeline(conn, commands)

    {:ok, job}
  end
end
