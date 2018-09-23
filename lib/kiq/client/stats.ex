defmodule Kiq.Client.Stats do
  @moduledoc false

  import Redix, only: [pipeline: 2]

  alias Kiq.{Heartbeat, RunningJob, Timestamp}

  @typep conn :: GenServer.server()
  @typep resp :: :ok | {:error, atom()}

  @spec record_heart(heartbeat :: Heartbeat.t(), conn :: conn()) :: resp()
  def record_heart(%Heartbeat{} = heartbeat, conn) do
    %Heartbeat{busy: busy, identity: key, quiet: quiet, running: running} = heartbeat

    wkey = "#{key}:workers"
    beat = Timestamp.unix_now()
    info = Jason.encode!(heartbeat)

    commands = [
      ["MULTI"],
      ["SADD", "processes", key],
      ["HMSET", key, "info", info, "beat", beat, "busy", busy, "quiet", quiet],
      ["EXPIRE", key, 60],
      ["DEL", wkey],
      ["HMSET" | [wkey | Enum.flat_map(running, &running_detail/1)]],
      ["EXPIRE", wkey, 60],
      ["EXEC"]
    ]

    with {:ok, _result} <- pipeline(conn, commands), do: :ok
  end

  @spec record_stats(stats :: Keyword.t(), conn :: conn()) :: :ok
  def record_stats(stats, conn) when is_list(stats) do
    date = Timestamp.date_now()
    processed = Keyword.fetch!(stats, :success)
    failed = Keyword.fetch!(stats, :failure)

    commands = [
      ["MULTI"],
      ["INCRBY", "stat:processed", processed],
      ["INCRBY", "stat:processed:#{date}", processed],
      ["INCRBY", "stat:failed", failed],
      ["INCRBY", "stat:failed:#{date}", failed],
      ["EXEC"]
    ]

    {:ok, _result} = pipeline(conn, commands)

    :ok
  end

  @spec remove_heart(heartbeat :: Heartbeat.t(), conn :: conn()) :: :ok
  def remove_heart(%Heartbeat{} = heartbeat, conn) do
    %Heartbeat{identity: key} = heartbeat

    commands = [["SREM", "processes", key], ["DEL", "#{key}:workers"]]

    {:ok, _result} = pipeline(conn, commands)

    :ok
  end

  # Helpers

  defp running_detail({_jid, %RunningJob{key: key, encoded: encoded}}), do: [key, encoded]
end
