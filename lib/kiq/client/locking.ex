defmodule Kiq.Client.Locking do
  @moduledoc false

  import Redix, only: [command!: 2]

  @typep conn :: GenServer.server()

  @spec locked?(conn(), binary(), binary(), pos_integer()) :: boolean()
  def locked?(conn, key, identity, ttl) when is_binary(identity) and ttl > 0 do
    command!(conn, ["SET", key, identity, "EX", to_string(ttl), "NX"]) == "OK"
  end
end
