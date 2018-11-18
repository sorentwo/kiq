defmodule Kiq.Client.Cleanup do
  @moduledoc false

  import Redix, only: [command: 2, noreply_command: 2, noreply_pipeline: 2]
  import Kiq.Naming, only: [backup_name: 2, unlock_name: 1]

  alias Kiq.{Job, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: :ok | {:error, atom() | Redix.Error.t()}

  @dead_set "dead"
  @static_keys ["leadership", "processes", "dead", "retry", "schedule"]

  @spec clear(conn()) :: resp()
  def clear(conn) do
    {:ok, queues} = command(conn, ["KEYS", "queue*"])
    {:ok, unique} = command(conn, ["KEYS", "unique:*"])
    {:ok, stats} = command(conn, ["KEYS", "stat:*"])

    keys = @static_keys ++ queues ++ unique ++ stats

    noreply_command(conn, ["DEL" | keys])
  end

  @spec kill(conn(), Job.t(), limit: pos_integer(), timeout: pos_integer()) :: resp()
  def kill(conn, %Job{} = job, limit: limit, timeout: timeout) do
    timeout_in = Timestamp.unix_in(-timeout)

    commands = [
      ["ZADD", @dead_set, Timestamp.to_score(), Job.encode(job)],
      ["ZREMRANGEBYSCORE", @dead_set, "-inf", Timestamp.to_score(timeout_in)],
      ["ZREMRANGEBYRANK", @dead_set, "0", to_string(-limit)]
    ]

    noreply_pipeline(conn, commands)
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
