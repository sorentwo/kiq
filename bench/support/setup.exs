defmodule Bench.Kiq do
  use Kiq, queues: [bench: 10]

  @impl true
  def init(_reason, opts) when is_list(opts) do
    redis_url = System.get_env("REDIS_URL") || "redis://localhost:6379/5"

    {:ok, Keyword.put(opts, :client_opts, [redis_url: redis_url])}
  end

  def pid_to_bin(pid) do
    pid
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  def bin_to_pid(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end

# Silence noise from the logger
Logger.configure(level: :warn)

{:ok, _pid} = Bench.Kiq.start_link()

:ok = Bench.Kiq.clear()
