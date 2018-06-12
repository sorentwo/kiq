defmodule Kiq.Timestamp do
  @moduledoc false

  @type t :: float()

  @doc false
  @spec unix_now() :: float()
  def unix_now do
    DateTime.utc_now()
    |> DateTime.to_unix(:microseconds)
    |> to_float()
  end

  @doc false
  @spec unix_in(offset :: integer(), unit :: atom()) :: float()
  def unix_in(offset, unit \\ :seconds) when is_integer(offset) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(offset, unit)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:microseconds)
    |> to_float()
  end

  @doc false
  @spec to_score(time :: DateTime.t() | integer() | float()) :: binary()
  def to_score(time \\ DateTime.utc_now())

  def to_score(%DateTime{} = time) do
    time
    |> DateTime.to_unix(:microseconds)
    |> to_score()
  end

  def to_score(time) when is_integer(time) do
    time
    |> to_float()
    |> to_score()
  end

  def to_score(time) when is_float(time) do
    Float.to_string(time)
  end

  defp to_float(timestamp), do: timestamp / 1_000_000.0
end
