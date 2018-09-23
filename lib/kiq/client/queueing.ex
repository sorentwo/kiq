defmodule Kiq.Client.Queueing do
  @moduledoc false

  import Redix, only: [command: 2, pipeline: 2]

  alias Kiq.{Job, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: {:ok, Job.t()}

  @retry_set "retry"
  @schedule_set "schedule"

  @spec enqueue(job :: Job.t(), conn :: conn()) :: resp()
  def enqueue(%Job{} = job, conn) do
    job
    |> Job.apply_unique()
    |> Job.apply_expiry()
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

  @spec retry(job :: Job.t(), conn :: conn()) :: resp()
  def retry(%Job{} = job, conn) do
    schedule_job(job, @retry_set, conn)
  end

  @spec dequeue(queue :: binary(), count :: pos_integer(), conn :: conn()) :: list(iodata())
  def dequeue(queue, count, conn) when is_binary(queue) and is_integer(count) do
    commands = for _ <- 1..count, do: ["RPOPLPUSH", queue_name(queue), backup_name(queue)]

    {:ok, results} = pipeline(conn, commands)

    Enum.filter(results, & &1)
  end

  @spec deschedule(set :: binary(), conn :: conn()) :: :ok
  def deschedule(set, conn) when is_binary(set) do
    max_score = Timestamp.to_score()

    with {:ok, [_ | _] = jobs} <- command(conn, ["ZRANGEBYSCORE", set, 0, max_score]),
         rem_commands = Enum.map(jobs, &["ZREM", set, &1]),
         {:ok, rem_counts} = pipeline(conn, rem_commands) do
      jobs
      |> Enum.zip(rem_counts)
      |> Enum.filter(fn {_job, count} -> count > 0 end)
      |> Enum.map(fn {job, _count} -> Job.decode(job) end)
      |> Enum.each(&push_job(&1, conn))
    end

    :ok
  end

  @spec resurrect(queue :: binary(), conn :: conn()) :: :ok
  def resurrect(queue, conn) when is_binary(queue) do
    with {:ok, count} when count > 0 <- command(conn, ["LLEN", backup_name(queue)]) do
      commands = for _ <- 1..count, do: ["RPOPLPUSH", backup_name(queue), queue_name(queue)]

      {:ok, _results} = pipeline(conn, commands)
    end

    :ok
  end

  # Helpers

  defp queue_name(queue), do: "queue:#{queue}"

  defp backup_name(queue), do: "queue:#{queue}:backup"

  defp unlock_name(token), do: "unique:#{token}"

  defp check_unique(%Job{unlocks_at: unlocks_at} = job, conn) when is_float(unlocks_at) do
    unlocks_in = trunc((unlocks_at - Timestamp.unix_now()) * 1_000)

    command = ["SET", unlock_name(job.unique_token), unlocks_at, "PX", unlocks_in, "NX"]

    case command(conn, command) do
      {:ok, "OK"} -> {:ok, job}
      {:ok, _result} -> {:locked, job}
    end
  end

  defp check_unique(job, _client), do: {:ok, job}

  defp push_job(%Job{queue: queue} = job, conn) do
    job = %Job{job | enqueued_at: Timestamp.unix_now()}

    commands = [
      ["SADD", "queues", queue],
      ["LPUSH", queue_name(queue), Job.encode(job)]
    ]

    {:ok, _result} = pipeline(conn, commands)

    {:ok, job}
  end

  defp schedule_job(%Job{at: at} = job, set, conn) do
    score = Timestamp.to_score(at)

    {:ok, _result} = command(conn, ["ZADD", set, score, Job.encode(job)])

    {:ok, job}
  end
end
