defmodule Kiq.Client.Stats do
  @moduledoc false

  import Redix, only: [noreply_pipeline: 2]

  alias Kiq.{Heartbeat, RunningJob, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: :ok | {:error, atom() | Redix.Error.t()}

  @spec record_heart(conn(), Heartbeat.t()) :: resp()
  def record_heart(conn, %Heartbeat{} = heartbeat) do
    %Heartbeat{busy: busy, identity: key, quiet: quiet, running: running} = heartbeat

    wkey = "#{key}:workers"
    beat = Timestamp.unix_now() |> to_string()
    info = Jason.encode!(heartbeat)

    commands = [
      ["SADD", "processes", key],
      ["HMSET", key, "info", info, "beat", to_string(beat)],
      ["HMSET", key, "busy", to_string(busy), "quiet", to_string(quiet)],
      ["EXPIRE", key, "60"],
      ["DEL", wkey],
      ["HMSET" | [wkey | Enum.flat_map(running, &running_detail/1)]],
      ["EXPIRE", wkey, "60"]
    ]

    noreply_pipeline(conn, commands)
  end

  @spec record_stats(conn(), Keyword.t()) :: resp()
  def record_stats(conn, stats) when is_list(stats) do
    date = Timestamp.date_now()
    processed = Keyword.fetch!(stats, :success)
    failed = Keyword.fetch!(stats, :failure)

    commands = [
      ["INCRBY", "stat:processed", processed],
      ["INCRBY", "stat:processed:#{date}", processed],
      ["INCRBY", "stat:failed", failed],
      ["INCRBY", "stat:failed:#{date}", failed]
    ]

    noreply_pipeline(conn, commands)
  end

  @spec remove_heart(conn(), Heartbeat.t()) :: resp()
  def remove_heart(conn, %Heartbeat{} = heartbeat) do
    %Heartbeat{identity: key} = heartbeat

    commands = [["SREM", "processes", key], ["DEL", "#{key}:workers"]]

    noreply_pipeline(conn, commands)
  end

  # Helpers

  defp running_detail({_jid, %RunningJob{key: key, encoded: encoded}}), do: [key, encoded]
end
