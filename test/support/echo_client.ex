defmodule Kiq.EchoClient do
  use GenServer

  def start_link(opts) do
    {name, opts} =
      opts
      |> Keyword.put_new(:test_pid, self())
      |> Keyword.pop(:name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    {:ok, opts}
  end

  def handle_call(message, _from, state) do
    send(state[:test_pid], message)

    {:reply, :ok, state}
  end
end

