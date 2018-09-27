defmodule Kiq.Client.Introspection do
  @moduledoc false

  import Redix, only: [command: 2]

  alias Kiq.Job

  @typep conn :: GenServer.server()

  @spec jobs(conn(), binary()) :: list(Job.t())
  def jobs(conn, queue) when is_binary(queue) do
    {:ok, results} = command(conn, ["LRANGE", "queue:#{queue}", "0", "-1"])

    Enum.map(results, &Job.decode/1)
  end

  @spec queue_size(conn(), binary()) :: non_neg_integer()
  def queue_size(conn, queue) when is_binary(queue) do
    {:ok, count} = command(conn, ["LLEN", "queue:#{queue}"])

    count
  end

  @spec set_size(conn(), binary()) :: non_neg_integer()
  def set_size(conn, set) when is_binary(set) do
    {:ok, count} = command(conn, ["ZCOUNT", set, "-inf", "+inf"])

    count
  end
end
