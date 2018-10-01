defmodule Kiq.EchoConsumer do
  use GenStage

  def start_link(opts) do
    {name, opts} =
      opts
      |> Keyword.put_new(:test_pid, self())
      |> Keyword.pop(:name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    {args, opts} = Keyword.split(opts, [:config, :test_pid])

    {:consumer, args, opts}
  end

  def handle_events(events, _from, state) do
    test_pid = Keyword.fetch!(state, :test_pid)

    for event <- events, do: send(test_pid, event)

    {:noreply, [], state}
  end
end
