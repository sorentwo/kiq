defmodule Kiq.Client.Introspection do
  @moduledoc false

  import Redix, only: [command: 2, pipeline: 2]
  import Kiq.Naming, only: [queue_name: 1, backup_name: 2, unlock_name: 1]

  alias Kiq.Job

  @typep conn :: GenServer.server()
  @typep queue :: binary()
  @typep identity :: binary()

  @spec jobs(conn(), queue()) :: list(Job.t())
  def jobs(conn, queue) when is_binary(queue) do
    {:ok, results} = command(conn, ["LRANGE", queue_name(queue), "0", "-1"])

    Enum.map(results, &Job.decode/1)
  end

  @spec retries(conn()) :: list(Job.t())
  def retries(conn) do
    {:ok, results} = command(conn, ["ZRANGEBYSCORE", "retry", "-inf", "+inf"])

    Enum.map(results, &Job.decode/1)
  end

  @spec queue_size(conn(), queue()) :: non_neg_integer()
  def queue_size(conn, queue) when is_binary(queue) do
    {:ok, count} = command(conn, ["LLEN", queue_name(queue)])

    count
  end

  @spec backup_size(conn(), identity(), queue()) :: non_neg_integer()
  def backup_size(conn, identity, queue) when is_binary(queue) do
    {:ok, count} = command(conn, ["LLEN", backup_name(identity, queue)])

    count
  end

  @spec set_size(conn(), queue()) :: non_neg_integer()
  def set_size(conn, set) when is_binary(set) do
    {:ok, count} = command(conn, ["ZCOUNT", set, "-inf", "+inf"])

    count
  end

  @spec locked?(conn(), Job.t()) :: boolean()
  def locked?(conn, %Job{} = job) do
    {:ok, 1} == command(conn, ["EXISTS", unlock_name(job.unique_token)])
  end

  @spec alive?(conn(), identity()) :: boolean()
  def alive?(conn, identity) when is_binary(identity) do
    {:ok, 1} == command(conn, ["SISMEMBER", "processes", identity])
  end

  @spec job_stats(conn()) :: %{processed: non_neg_integer(), failed: non_neg_integer()}
  def job_stats(conn) do
    to_int = fn
      nil -> 0
      val -> String.to_integer(val)
    end

    commands = [["GET", "stat:processed"], ["GET", "stat:failed"]]

    {:ok, [proc_count, fail_count]} = pipeline(conn, commands)

    %{processed: to_int.(proc_count), failed: to_int.(fail_count)}
  end

  @spec heartbeat(conn(), identity()) :: map()
  def heartbeat(conn, identity) when is_binary(identity) do
    hash_to_map(conn, identity)
  end

  @spec workers(conn(), identity()) :: map()
  def workers(conn, identity) when is_binary(identity) do
    hash_to_map(conn, "#{identity}:workers")
  end

  defp hash_to_map(conn, hash_key) do
    {:ok, values} = command(conn, ["HGETALL", hash_key])

    values
    |> Enum.chunk_every(2)
    |> Enum.into(%{}, fn [key, val] ->
      {String.to_atom(key), Jason.decode!(val, keys: :atoms)}
    end)
  end
end
