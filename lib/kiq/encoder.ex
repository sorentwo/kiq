defmodule Kiq.Encoder do
  @moduledoc """
  This module wraps `Jason.encode/1` to provide consistent and safe JSON encoding.

  Typically this module shouldn't be used outside of Kiq, but the function is
  documented for reference on how job arguments are encoded.
  """

  @doc """
  Safely encode terms into JSON, if possible.

  Some Elixir/Erlang types can't be represented as JSON. To make encoding as reliable as possible
  the `encode/1` function attempts to convert incompatible terms into JSON friendly values.

  The following sanitization is applied (recursively):

  * `struct` - Converted to a map using `Map.from_struct/1`
  * `tuple` — Converted to a list
  * `pid`, `port`, `reference` — Converted to a string using inspect, i.e. "#PID<0.101.0>"
  """
  @spec encode(any()) :: binary()
  def encode(term) do
    case Jason.encode(term) do
      {:ok, encoded} ->
        encoded

      {:error, %Protocol.UndefinedError{}} ->
        term
        |> sanitize()
        |> Jason.encode!()
    end
  end

  defp sanitize(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> sanitize()
  end

  defp sanitize(map) when is_map(map) do
    for {key, val} <- map, into: %{}, do: {key, sanitize(val)}
  end

  defp sanitize(list) when is_list(list) do
    for term <- list, do: sanitize(term)
  end

  defp sanitize(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> sanitize()
  end

  defp sanitize(input) when is_pid(input) or is_port(input) or is_reference(input) do
    inspect(input)
  end

  defp sanitize(term), do: term
end
