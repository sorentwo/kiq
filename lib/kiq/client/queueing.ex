defmodule Kiq.Client.Queueing do
  @moduledoc false

  import Redix
  import Kiq.Naming

  alias Kiq.{Job, Script, Timestamp}

  @typep conn :: GenServer.server()

  @external_resource Script.path("dequeue")
  @external_resource Script.path("deschedule")
  @external_resource Script.path("enqueue")
  @dequeue_sha Script.hash("dequeue")
  @enqueue_sha Script.hash("enqueue")
  @deschedule_sha Script.hash("deschedule")

  @spec enqueue(conn(), list(Job.t())) :: :ok
  def enqueue(_conn, []), do: :ok

  def enqueue(conn, jobs) when is_list(jobs) do
    commands = for job <- jobs, do: enqueue_command(job)

    noreply_pipeline!(conn, commands)
  end

  @spec dequeue(conn(), binary(), binary(), pos_integer()) :: list(iodata())
  def dequeue(conn, queue, identity, count) when is_binary(queue) and is_integer(count) do
    queue_name = queue_name(queue)
    backup_name = backup_name(identity, queue)

    command!(conn, ["EVALSHA", @dequeue_sha, "2", queue_name, backup_name, to_string(count)])
  end

  @spec deschedule(conn(), binary()) :: :ok
  def deschedule(conn, set) when is_binary(set) do
    noreply_command!(conn, ["EVALSHA", @deschedule_sha, "1", set, Timestamp.to_score()])
  end

  @spec retry(conn(), Job.t()) :: :ok
  def retry(conn, %Job{at: at, retry: retry, retry_count: count} = job)
      when is_integer(retry) or (retry == true and count > 0) do
    noreply_command!(conn, ["ZADD", "retry", Timestamp.to_score(at), Job.encode(job)])
  end

  # Helpers

  defp enqueue_command(%Job{queue: queue} = job) do
    {job, enqueue_at} = maybe_enqueue_at(job)
    {unique_key, unlocks_in} = maybe_unlocks_in(job)

    eval_keys = ["EVALSHA", @enqueue_sha, "1", unique_key]
    eval_args = [Job.encode(job), queue, enqueue_at, unlocks_in]

    eval_keys ++ eval_args
  end

  defp maybe_enqueue_at(%Job{at: at} = job) do
    if is_float(at) do
      {job, Timestamp.to_score(job.at)}
    else
      {%{job | enqueued_at: Timestamp.unix_now()}, nil}
    end
  end

  defp maybe_unlocks_in(%Job{unique_token: unique_token, unlocks_at: unlocks_at}) do
    if is_float(unlocks_at) do
      unique_key = unlock_name(unique_token)
      unlocks_in = trunc((unlocks_at - Timestamp.unix_now()) * 1_000)

      {unique_key, to_string(unlocks_in)}
    else
      {nil, nil}
    end
  end
end
