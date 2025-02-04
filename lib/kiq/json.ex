defmodule Kiq.JSON do
  @moduledoc false

  # Delegates to JSON in Elixir v1.18+ or Jason for earlier versions

  cond do
    Code.ensure_loaded?(JSON) ->
      defdelegate decode(data), to: JSON
      defdelegate encode!(data), to: JSON
      defdelegate encode_to_iodata!(data), to: JSON
      def json_encoder, do: JSON.Encoder

      def decode!(data, opts \\ []) do
        if Keyword.get(opts, :atomize_keys) do
          {decoded, _acc, _rest} = JSON.decode(data, %{}, object_push: fn k, v, acc -> [{String.to_atom(k), v} | acc] end)

          decoded
        else
          JSON.decode!(data)
        end
      end

    Code.ensure_loaded?(Jason) ->
      defdelegate decode(data), to: Jason
      defdelegate encode!(data), to: Jason
      defdelegate encode_to_iodata!(data), to: Jason
      def json_encoder, do: Jason.Encoder

      def decode!(data, opts \\ []) do
        if Keyword.get(opts, :atomize_keys) do
          Jason.decode!(data, keys: :atoms)
        else
          Jason.decode!(data)
        end
      end

    true ->
      message = "Missing a compatible JSON library, add `:jason` to your deps."

      IO.warn(message, Macro.Env.stacktrace(__ENV__))
  end
end
