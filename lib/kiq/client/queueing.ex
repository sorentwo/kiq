defmodule Kiq.Client.Queueing do
  @moduledoc false

  import Redix, only: [command!: 2, noreply_command!: 2, noreply_pipeline!: 2, pipeline!: 2]
  import Kiq.Naming, only: [queue_name: 1, backup_name: 2, unlock_name: 1]

  alias Kiq.{Job, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: {:ok, Job.t()}

  @retry_set "retry"
  @schedule_set "schedule"

  @dequeue_script """
    local index = tonumber(ARGV[1])
    local jobs = {}

    while (index > 0) do
      local job = redis.call("rpop", KEYS[1])

      if job then
        local jid = string.match(job, '"jid":"(%w+)"')

        redis.call("hset", KEYS[2], jid, job)
        table.insert(jobs, job)

        index = index - 1
      else
        break
      end
    end

    return jobs
  """

  @spec enqueue(conn(), Job.t()) :: resp()
  def enqueue(conn, %Job{} = job) do
    job
    |> check_unique(conn)
    |> case do
      {:ok, %Job{at: at} = job} when is_float(at) ->
        schedule_job(job, @schedule_set, conn)

      {:ok, job} ->
        push_job(job, conn)

      {:locked, job} ->
        {:ok, job}
    end
  end

  @spec retry(conn(), Job.t()) :: resp()
  def retry(conn, %Job{retry: retry, retry_count: count} = job)
      when is_integer(retry) or (retry == true and count > 0) do
    schedule_job(job, @retry_set, conn)
  end

  @spec dequeue(conn(), binary(), binary(), pos_integer()) :: list(iodata())
  def dequeue(conn, queue, identity, count) when is_binary(queue) and is_integer(count) do
    queue_name = queue_name(queue)
    backup_name = backup_name(identity, queue)

    command!(conn, ["EVAL", @dequeue_script, "2", queue_name, backup_name, count])
  end

  @spec deschedule(conn(), binary()) :: :ok
  def deschedule(conn, set) when is_binary(set) do
    max_score = Timestamp.to_score()

    with [_ | _] = jobs <- command!(conn, ["ZRANGEBYSCORE", set, "0", max_score]) do
      rem_commands = Enum.map(jobs, &["ZREM", set, &1])
      rem_counts = pipeline!(conn, rem_commands)

      jobs
      |> Enum.zip(rem_counts)
      |> Enum.filter(fn {_job, count} -> count > 0 end)
      |> Enum.map(fn {job, _count} -> Job.decode(job) end)
      |> Enum.each(&push_job(&1, conn))
    end

    :ok
  end

  # Helpers

  defp check_unique(%{unlocks_at: unlocks_at} = job, conn) when is_float(unlocks_at) do
    unlocks_in = trunc((unlocks_at - Timestamp.unix_now()) * 1_000)

    command = [
      "SET",
      unlock_name(job.unique_token),
      to_string(unlocks_at),
      "PX",
      to_string(unlocks_in),
      "NX"
    ]

    case command!(conn, command) do
      "OK" -> {:ok, job}
      _res -> {:locked, job}
    end
  end

  defp check_unique(job, _client), do: {:ok, job}

  defp push_job(%{queue: queue} = job, conn) do
    job = %Job{job | enqueued_at: Timestamp.unix_now()}

    commands = [
      ["MULTI"],
      ["SADD", "queues", queue],
      ["LPUSH", queue_name(queue), Job.encode(job)],
      ["EXEC"]
    ]

    :ok = noreply_pipeline!(conn, commands)

    {:ok, job}
  end

  defp schedule_job(%Job{at: at} = job, set, conn) do
    score = Timestamp.to_score(at)

    :ok = noreply_command!(conn, ["ZADD", set, score, Job.encode(job)])

    {:ok, job}
  end
end
