defmodule Kiq.Client.Leadership do
  @moduledoc false

  import Redix, only: [command!: 2]

  alias Kiq.Script

  @typep conn :: GenServer.server()
  @typep identity :: binary()
  @typep ttl :: pos_integer()

  @key "leadership"

  @external_resource Script.path("resign")
  @external_resource Script.path("reelect")
  @resign_sha Script.hash("resign")
  @reelect_sha Script.hash("reelect")

  @spec inaugurate(conn(), identity(), ttl()) :: boolean()
  def inaugurate(conn, identity, ttl) when is_binary(identity) and ttl > 0 do
    command!(conn, ["SET", @key, identity, "PX", to_string(ttl), "NX"]) == "OK"
  end

  @spec reelect(conn(), identity(), ttl()) :: boolean()
  def reelect(conn, identity, ttl) when is_binary(identity) and ttl > 0 do
    command!(conn, ["EVALSHA", @reelect_sha, "1", @key, identity, to_string(ttl)]) > 0
  end

  @spec resign(conn(), identity()) :: boolean()
  def resign(conn, identity) when is_binary(identity) do
    command!(conn, ["EVALSHA", @resign_sha, "1", @key, identity]) > 0
  end
end
