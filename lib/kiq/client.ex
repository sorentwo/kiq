defmodule Kiq.Client do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Heartbeat, Job, RunningJob, Timestamp}

  @type client :: GenServer.server()
  @type queue :: binary() | atom()
  @type options :: [config: Config.t(), name: GenServer.name()]
  @type set :: binary() | atom()
  @type stat_report :: [success: integer(), failure: integer()]

  @retry_set "retry"
  @schedule_set "schedule"

  defmodule State do
    @moduledoc false

    @enforce_keys [:conn]
    defstruct conn: nil
  end

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec enqueue(client(), Job.t()) :: {:ok, Job.t()}
  def enqueue(client, %Job{retry: retry, retry_count: count} = job)
      when is_integer(retry) or (retry == true and count > 0) do
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

  ## Introspection

  @doc false
  @spec jobs(client(), queue()) :: list(Job.t())
  def jobs(client, queue) when is_binary(queue) do
    GenServer.call(client, {:jobs, queue})
  end

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

  ## Clearing & Removal

  @doc false
  @spec clear_all(client()) :: :ok
  def clear_all(client) do
    GenServer.call(client, :clear)
  end

  @doc false
  @spec remove_backup(client(), Job.t()) :: :ok
  def remove_backup(client, %Job{queue: queue} = job) when is_binary(queue) do
    GenServer.call(client, {:remove_backup, job})
  end

  ## Stats

  @doc false
  @spec record_heart(client(), Heartbeat.t()) :: :ok
  def record_heart(client, %Heartbeat{} = heartbeat) do
    GenServer.call(client, {:record_heart, heartbeat})
  end

  @doc false
  @spec record_stats(client(), stat_report()) :: :ok
  def record_stats(client, stats) when is_list(stats) do
    GenServer.call(client, {:record_stats, stats})
  end

  @doc false
  @spec remove_heart(client(), Heartbeat.t()) :: :ok
  def remove_heart(client, %Heartbeat{} = heartbeat) do
    GenServer.call(client, {:remove_heart, heartbeat})
  end

  # Server

  @impl GenServer
  def init(config: %Config{client_opts: client_opts}) do
    redis_url = Keyword.fetch!(client_opts, :redis_url)

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

  def handle_call({:jobs, queue}, _from, %State{conn: conn} = state) do
    {:ok, results} = Redix.command(conn, ["LRANGE", queue_name(queue), 0, -1])

    jobs = Enum.map(results, &Job.decode/1)

    {:reply, jobs, state}
  end

  def handle_call({:queue_size, queue}, _from, %State{conn: conn} = state) do
    {:ok, count} = Redix.command(conn, ["LLEN", queue_name(queue)])

    {:reply, count, state}
  end

  def handle_call({:set_size, set}, _from, %State{conn: conn} = state) do
    {:ok, count} = Redix.command(conn, ["ZCOUNT", set, "-inf", "+inf"])

    {:reply, count, state}
  end

  ## Clearing & Removal

  def handle_call(:clear, _from, %State{conn: conn} = state) do
    {:ok, queues} = Redix.command(conn, ["KEYS", "queue*"])
    {:ok, _reply} = Redix.command(conn, ["DEL", @retry_set, @schedule_set | queues])

    {:reply, :ok, state}
  end

  def handle_call({:remove_backup, job}, _from, %State{conn: conn} = state) do
    {:ok, _result} = Redix.command(conn, ["LREM", backup_name(job.queue), "0", Job.encode(job)])

    {:reply, :ok, state}
  end

  ## Stats

  def handle_call({:record_heart, heartbeat}, _from, %State{conn: conn} = state) do
    %Heartbeat{busy: busy, identity: key, quiet: quiet, running: running} = heartbeat

    wkey = "#{key}:workers"
    beat = Timestamp.unix_now()
    info = Heartbeat.encode(heartbeat)

    commands = [
      ["MULTI"],
      ["SADD", "processes", key],
      ["HMSET", key, "info", info, "beat", beat, "busy", busy, "quiet", quiet],
      ["EXPIRE", key, 60],
      ["DEL", wkey],
      ["HMSET" | [wkey | Enum.flat_map(running, &running_detail/1)]],
      ["EXPIRE", wkey, 60],
      ["EXEC"]
    ]

    {:ok, _result} = Redix.pipeline(conn, commands)

    {:reply, :ok, state}
  end

  def handle_call({:record_stats, stats}, _from, %State{conn: conn} = state) do
    date = Timestamp.date_now()
    processed = Keyword.fetch!(stats, :success)
    failed = Keyword.fetch!(stats, :failure)

    commands = [
      ["INCRBY", "stat:processed", processed],
      ["INCRBY", "stat:processed:#{date}", processed],
      ["INCRBY", "stat:failed", failed],
      ["INCRBY", "stat:failed:#{date}", failed]
    ]

    {:ok, _result} = Redix.pipeline(conn, commands)

    {:reply, :ok, state}
  end

  def handle_call({:remove_heart, heartbeat}, _from, %State{conn: conn} = state) do
    %Heartbeat{identity: key} = heartbeat

    commands = [["SREM", "processes", key], ["DEL", "#{key}:workers"]]

    {:ok, _result} = Redix.pipeline(conn, commands)

    {:reply, :ok, state}
  end

  # Helpers

  defp queue_name(queue), do: "queue:#{queue}"

  defp backup_name(queue), do: "queue:#{queue}:backup"

  defp push_job(conn, %Job{queue: queue} = job) do
    job = %Job{job | enqueued_at: Timestamp.unix_now()}

    commands = [
      ["SADD", "queues", queue],
      ["LPUSH", queue_name(queue), Job.encode(job)]
    ]

    {:ok, _result} = Redix.pipeline(conn, commands)

    {:ok, job}
  end

  defp running_detail({_jid, %RunningJob{key: key, encoded: encoded}}), do: [key, encoded]
end
