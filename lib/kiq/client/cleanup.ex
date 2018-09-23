defmodule Kiq.Client.Cleanup do
  @moduledoc false

  import Redix, only: [command: 2]

  alias Kiq.Job

  @type conn :: GenServer.server()

  @static_keys ["retry", "schedule", "processes"]

  @spec clear_all(conn :: conn()) :: :ok
  def clear_all(conn) do
    {:ok, queues} = command(conn, ["KEYS", "queue*"])
    {:ok, unique} = command(conn, ["KEYS", "unique:*"])
    {:ok, stats} = command(conn, ["KEYS", "stat:*"])

    keys = @static_keys ++ queues ++ unique ++ stats

    {:ok, _reply} = command(conn, ["DEL" |  keys])

    :ok
  end

  @spec remove_backup(job :: Job.t(), conn :: conn()) :: :ok
  def remove_backup(%Job{queue: queue} = job, conn) do
    {:ok, _result} = command(conn, ["LREM", "queue:#{queue}:backup", "0", Job.encode(job)])

    :ok
  end

  @spec unlock_job(job :: Job.t(), conn :: conn()) :: :ok
  def unlock_job(%Job{unique_token: token}, conn) do
    {:ok, _result} = command(conn, ["DEL", "unique:#{token}"])

    :ok
  end
end
