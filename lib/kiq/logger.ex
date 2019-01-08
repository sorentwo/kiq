defmodule Kiq.Logger do
  @moduledoc false

  require Logger

  alias Kiq.Encoder

  @spec log(map()) :: :ok
  def log(payload) when is_map(payload) do
    Logger.info(fn ->
      payload
      |> Map.put(:source, "kiq")
      |> Encoder.encode()
    end)
  end
end
