defmodule Kiq.Identity do
  @moduledoc false

  @spec identity(env :: map()) :: <<_::16, _::_*8>>
  def identity(env \\ System.get_env()) do
    "#{hostname(env)}:#{pid()}:#{nonce()}"
  end

  @spec hostname(env :: map()) :: :inet.hostname()
  def hostname(env \\ System.get_env()) do
    Map.get_lazy(env, "DYNO", fn ->
      :inet.gethostname()
      |> elem(1)
      |> to_string()
    end)
  end

  @spec pid() :: binary()
  def pid do
    "~p"
    |> :io_lib.format([self()])
    |> to_string()
  end

  @spec nonce() :: binary()
  def nonce(size \\ 8) when size > 0 do
    size
    |> :crypto.strong_rand_bytes()
    |> Base.hex_encode32()
    |> String.slice(0..(size - 1))
  end
end
