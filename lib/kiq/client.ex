defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Job, Timestamp}

  @type client :: GenServer.server()
  @type queue :: binary() | atom()
  @type set :: binary() | atom()

  @retry_set "retry"
  @schedule_set "schedule"

  defmodule State do
    @moduledoc false

    @enforce_keys [:conn]
    defstruct conn: nil
  end

  @doc false
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec enqueue(client(), Job.t()) :: Job.t()
  def enqueue(client, %Job{retry: true, retry_count: count} = job) when count > 0 do
    GenServer.call(client, {:enqueue_at, job, @retry_set})
  end

  def enqueue(client, %Job{at: at} = job) when is_float(at) do
    GenServer.call(client, {:enqueue_at, job, @schedule_set})
  end

  def enqueue(client, %Job{queue: queue} = job) when is_binary(queue) do
    GenServer.call(client, {:enqueue, job})
  end

  @doc false
  @spec dequeue(client(), queue(), pos_integer()) :: list(Job.t())
  def dequeue(client, queue, count) when is_binary(queue) and is_integer(count) do
    GenServer.call(client, {:dequeue, queue, count})
  end

  @doc false
  @spec deschedule(client(), set()) :: :ok
  def deschedule(client, set) when is_binary(set) do
    GenServer.call(client, {:deschedule, set})
  end

  @doc false
  @spec resurrect(client(), queue()) :: :ok
  def resurrect(client, queue) when is_binary(queue) do
    GenServer.call(client, {:resurrect, queue})
  end

  # Introspection

  @doc false
  @spec queue_size(client(), queue()) :: pos_integer()
  def queue_size(client, queue) when is_binary(queue) do
    GenServer.call(client, {:queue_size, queue})
  end

  @doc false
  @spec set_size(client(), set()) :: pos_integer()
  def set_size(client, set) when is_binary(set) do
    GenServer.call(client, {:set_size, set})
  end

  # Clearing & Removal

  @doc false
  @spec clear_queue(client(), queue()) :: :ok
  def clear_queue(client, queue) when is_binary(queue) do
    GenServer.call(client, {:clear, [queue_name(queue), backup_name(queue)]})
  end

  @doc false
  @spec clear_set(client(), queue()) :: :ok
  def clear_set(client, set) when is_binary(set) do
    GenServer.call(client, {:clear, [set]})
  end

  @doc false
  @spec remove_backup(client(), Job.t()) :: :ok
  def remove_backup(client, %Job{queue: queue} = job) when is_binary(queue) do
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

  def handle_call({:enqueue_at, job, set}, _from, %State{conn: conn} = state) do
    score = Timestamp.to_score(job.at)

    {:ok, _result} = Redix.command(conn, ["ZADD", set, score, Job.encode(job)])

    {:reply, {:ok, job}, state}
  end

  def handle_call({:dequeue, _queue, 0}, _from, state) do
    {:reply, [], state}
  end

  def handle_call({:dequeue, queue, count}, _from, %State{conn: conn} = state) do
    commands = for _ <- 1..count, do: ["RPOPLPUSH", queue_name(queue), backup_name(queue)]

    {:ok, results} = Redix.pipeline(conn, commands)

    {:reply, Enum.filter(results, & &1), state}
  end

  def handle_call({:deschedule, set}, _from, %State{conn: conn} = state) do
    max_score = Timestamp.to_score()

    with {:ok, [_ | _] = jobs} <- Redix.command(conn, ["ZRANGEBYSCORE", set, 0, max_score]),
         rem_commands = Enum.map(jobs, &["ZREM", set, &1]),
         {:ok, rem_counts} = Redix.pipeline(conn, rem_commands) do
      jobs
      |> Enum.zip(rem_counts)
      |> Enum.filter(fn {_job, count} -> count > 0 end)
      |> Enum.map(fn {job, _count} -> Job.decode(job) end)
      |> Enum.each(&push_job(conn, &1))
    end

    {:reply, :ok, state}
  end

  def handle_call({:resurrect, queue}, _from, %State{conn: conn} = state) do
    with {:ok, count} when count > 0 <- Redix.command(conn, ["LLEN", backup_name(queue)]) do
      commands = for _ <- 1..count, do: ["RPOPLPUSH", backup_name(queue), queue_name(queue)]

      {:ok, _results} = Redix.pipeline(conn, commands)
    end

    {:reply, :ok, state}
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
