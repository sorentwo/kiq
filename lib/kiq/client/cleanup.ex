defmodule Kiq.Client.Cleanup do
  @moduledoc false

  import Redix, only: [command: 2]

  alias Kiq.Job

  @typep conn :: GenServer.server()

  @static_keys ["retry", "schedule", "processes"]

  @spec clear_all(conn()) :: :ok
  def clear_all(conn) do
    {:ok, queues} = command(conn, ["KEYS", "queue*"])
    {:ok, unique} = command(conn, ["KEYS", "unique:*"])
    {:ok, stats} = command(conn, ["KEYS", "stat:*"])

    keys = @static_keys ++ queues ++ unique ++ stats

    {:ok, _reply} = command(conn, ["DEL" | keys])

    :ok
  end

  @spec remove_backup(conn(), Job.t()) :: :ok
  def remove_backup(conn, %Job{queue: queue} = job) do
    {:ok, _result} = command(conn, ["LREM", "queue:#{queue}:backup", "0", Job.encode(job)])

    :ok
  end

  @spec unlock_job(conn(), Job.t()) :: :ok
  def unlock_job(conn, %Job{unique_token: token}) do
    {:ok, _result} = command(conn, ["DEL", "unique:#{token}"])

    :ok
  end
end
