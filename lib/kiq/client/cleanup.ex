defmodule Kiq.Client.Cleanup do
  @moduledoc false

  import Redix, only: [command: 2, noreply_command: 2]
  import Kiq.Naming, only: [backup_name: 2, unlock_name: 1]

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

  @spec remove_backup(conn(), binary(), Job.t()) :: resp()
  def remove_backup(conn, identity, %Job{jid: jid, queue: queue}) do
    noreply_command(conn, ["HDEL", backup_name(identity, queue), jid])
  end

  @spec unlock_job(conn(), Job.t()) :: resp()
  def unlock_job(conn, %Job{unique_token: token}) do
    noreply_command(conn, ["DEL", unlock_name(token)])
  end
end
