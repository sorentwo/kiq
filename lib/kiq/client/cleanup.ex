defmodule Kiq.Client.Cleanup do
  @moduledoc false

  import Redix, only: [command: 2, noreply_command: 2]

  alias Kiq.Job

  @typep conn :: GenServer.server()
  @typep resp :: :ok | {:error, atom() | Redix.Error.t()}

  @static_keys ["leadership", "processes", "retry", "schedule"]

  @spec clear(conn()) :: resp()
  def clear(conn) do
    {:ok, queues} = command(conn, ["KEYS", "queue*"])
    {:ok, unique} = command(conn, ["KEYS", "unique:*"])
    {:ok, stats} = command(conn, ["KEYS", "stat:*"])

    keys = @static_keys ++ queues ++ unique ++ stats

    noreply_command(conn, ["DEL" | keys])
  end

  @spec remove_backup(conn(), Job.t()) :: resp()
  def remove_backup(conn, %Job{queue: queue} = job) do
    noreply_command(conn, ["LREM", "queue:#{queue}:backup", "0", Job.encode(job)])
  end

  @spec unlock_job(conn(), Job.t()) :: resp()
  def unlock_job(conn, %Job{unique_token: token}) do
    noreply_command(conn, ["DEL", "unique:#{token}"])
  end
end
