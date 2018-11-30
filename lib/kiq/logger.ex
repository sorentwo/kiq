defmodule Kiq.Logger do
  @moduledoc false

  require Logger

  @spec log(map()) :: :ok
  def log(payload) when is_map(payload) do
    Logger.info(fn ->
      payload
      |> Map.put(:source, "kiq")
      |> Jason.encode!()
    end)
  end
end
