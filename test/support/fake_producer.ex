defmodule Kiq.FakeProducer do
  use GenStage

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(events: events) do
    {:producer, events}
  end

  def handle_call(_message, from, state) do
    GenStage.reply(from, :ok)

    {:noreply, [], state}
  end

  def handle_demand(_demand, events) do
    {:noreply, events, []}
  end
end
