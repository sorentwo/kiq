defmodule Kiq.Client.Queueing do
  @moduledoc false

  import Redix, only: [command!: 2, noreply_command!: 2, noreply_pipeline!: 2]
  import Kiq.Naming, only: [queue_name: 1, backup_name: 2, unlock_name: 1]

  alias Kiq.{Job, Script, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: {:ok, Job.t()}

  @retry_set "retry"
  @schedule_set "schedule"

  @external_resource Script.path("dequeue")
  @external_resource Script.path("deschedule")
  @dequeue_sha Script.hash("dequeue")
  @deschedule_sha Script.hash("deschedule")

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

  @spec dequeue(conn(), binary(), binary(), pos_integer()) :: list(iodata())
  def dequeue(conn, queue, identity, count) when is_binary(queue) and is_integer(count) do
    queue_name = queue_name(queue)
    backup_name = backup_name(identity, queue)

    command!(conn, ["EVALSHA", @dequeue_sha, "2", queue_name, backup_name, to_string(count)])
  end

  @spec deschedule(conn(), binary()) :: :ok
  def deschedule(conn, set) when is_binary(set) do
    conn
    |> command!(["EVALSHA", @deschedule_sha, "1", set, Timestamp.to_score()])
    |> Enum.map(&Job.decode/1)
    |> Enum.each(&push_job(&1, conn))

    :ok
  end

  @spec retry(conn(), Job.t()) :: resp()
  def retry(conn, %Job{retry: retry, retry_count: count} = job)
      when is_integer(retry) or (retry == true and count > 0) do
    schedule_job(job, @retry_set, conn)
  end

  # Helpers

  defp check_unique(%{unlocks_at: unlocks_at} = job, conn) when is_float(unlocks_at) do
    unlocks_in = trunc((unlocks_at - Timestamp.unix_now()) * 1_000)
    unlock_name = unlock_name(job.unique_token)

    command = ["SET", unlock_name, to_string(unlocks_at), "PX", to_string(unlocks_in), "NX"]

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
