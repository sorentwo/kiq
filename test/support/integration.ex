defmodule Kiq.Integration do
  use Kiq, queues: [integration: 3], pool_size: 1

  @impl Kiq
  def init(_reason, opts) do
    client_opts = [redis_url: redis_url()]

    {:ok, Keyword.put(opts, :client_opts, client_opts)}
  end

  defp redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/3"
  end
end

defmodule Kiq.Integration.Worker do
  use Kiq.Worker, queue: "integration"

  def perform([pid_bin, "SLOW"]) do
    pid = bin_to_pid(pid_bin)

    send(pid, :started)

    Process.sleep(1_000)

    send(pid, :stopped)
  end

  def perform([pid_bin, "FAIL"]) do
    pid_bin
    |> bin_to_pid()
    |> send(:failed)

    raise "bad stuff happened"
  end

  def perform([pid_bin, value]) do
    pid_bin
    |> bin_to_pid()
    |> send({:processed, value})
  end

  def pid_to_bin(pid \\ self()) do
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
