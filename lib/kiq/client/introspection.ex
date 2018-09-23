defmodule Kiq.Client.Introspection do
  @moduledoc false

  import Redix, only: [command: 2]

  alias Kiq.Job

  @typep conn :: GenServer.server()

  @spec jobs(queue :: binary(), conn :: conn()) :: list(Job.t())
  def jobs(queue, conn) when is_binary(queue) do
    {:ok, results} = command(conn, ["LRANGE", "queue:#{queue}", 0, -1])

    Enum.map(results, &Job.decode/1)
  end

  @spec queue_size(queue :: binary(), conn :: conn()) :: non_neg_integer()
  def queue_size(queue, conn) when is_binary(queue) do
    {:ok, count} = command(conn, ["LLEN", "queue:#{queue}"])

    count
  end

  @spec set_size(set :: binary(), conn :: conn()) :: non_neg_integer()
  def set_size(set, conn) when is_binary(set) do
    {:ok, count} = command(conn, ["ZCOUNT", set, "-inf", "+inf"])

    count
  end
end
