defmodule Kiq.Client.Leadership do
  @moduledoc false

  import Redix, only: [command!: 2]

  @typep conn :: GenServer.server()
  @typep identity :: binary()
  @typep ttl :: pos_integer()

  @key "leadership"

  @resign_script """
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  """

  @reelect_script """
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("pexpire", KEYS[1], ARGV[2])
    else
      return 0
    end
  """

  @spec inaugurate(conn(), identity(), ttl()) :: boolean()
  def inaugurate(conn, identity, ttl) when is_binary(identity) and ttl > 0 do
    command!(conn, ["SET", @key, identity, "PX", to_string(ttl), "NX"]) == "OK"
  end

  @spec reelect(conn(), identity(), ttl()) :: boolean()
  def reelect(conn, identity, ttl) when is_binary(identity) and ttl > 0 do
    command!(conn, ["EVAL", @reelect_script, "1", @key, identity, to_string(ttl)]) > 0
  end

  @spec resign(conn(), identity()) :: boolean()
  def resign(conn, identity) when is_binary(identity) do
    command!(conn, ["EVAL", @resign_script, "1", @key, identity])
  end
end
