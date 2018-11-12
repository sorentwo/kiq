defmodule Kiq.Client.Resurrection do
  @moduledoc false

  import Redix, only: [command!: 2]
  import Kiq.Naming, only: [queue_name: 1]

  alias Kiq.Script

  @typep conn :: GenServer.server()

  @external_resource Script.path("resurrect")
  @resurrect_sha Script.hash("resurrect")

  @spec resurrect(conn()) :: list(any())
  def resurrect(conn) do
    conn
    |> fetch_backups()
    |> remap_backups()
    |> prune_processes(conn)
    |> restore_backups(conn)
  end

  # Helpers

  defp fetch_backups(conn) do
    fetch_backups([], "0", conn)
  end

  # In most cases there won't be many backup lists, but it is best to use
  # `SCAN` instead of `KEYS` just in case there are dozens or hundreds of
  # backup queues.
  defp fetch_backups(backups, cursor, conn) do
    case command!(conn, ["SCAN", cursor, "MATCH", "queue:backup|*"]) do
      [_cursor, []] -> backups
      ["0", results] -> backups ++ results
      [cursor, results] -> fetch_backups(backups ++ results, cursor, conn)
    end
  end

  defp remap_backups(backups) do
    for backup <- backups do
      ["queue:backup", identity, queue] = String.split(backup, "|")

      {backup, identity, queue}
    end
  end

  # All active processes are recorded by the heartbeat reporter in the
  # `processes` hash. We shouldn't try to restore any backups when they are
  # being actively processed, so we drop backups from any live processes.
  defp prune_processes(backups, conn) do
    processes =
      conn
      |> command!(["SMEMBERS", "processes"])
      |> MapSet.new()

    Enum.reject(backups, fn {_backup, identity, _queue} ->
      MapSet.member?(processes, identity)
    end)
  end

  # Using a script ensures the resurrection happens atomically, helping us to avoid
  # race conditions.
  defp restore_backups(backups, conn) do
    for {backup, _identity, queue} <- backups do
      command!(conn, ["EVALSHA", @resurrect_sha, "2", backup, queue_name(queue)])
    end
  end
end
