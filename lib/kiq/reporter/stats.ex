defmodule Kiq.Reporter.Stats do
  @moduledoc false

  use GenStage

  alias Kiq.Client

  @behaviour GenStage

  defmodule State do
    @moduledoc false

    defstruct client: nil,
              success_count: 0,
              failure_count: 0,
              flush_interval: 1_000
  end

  @doc false
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @impl GenStage
  def init(opts) do
    {args, opts} = Keyword.split(opts, [:client, :flush_interval])

    Process.flag(:trap_exit, true)

    state =
      State
      |> struct(args)
      |> schedule_flush()

    {:consumer, state, opts}
  end

  @impl GenStage
  def handle_info(:flush, state) do
    state =
      state
      |> process_enqueued()
      |> schedule_flush()

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    state = Enum.reduce(events, state, &record_event/2)

    {:noreply, [], state}
  end

  @impl GenStage
  def terminate(_reason, state) do
    process_enqueued(state)

    :ok
  end

  # Helpers

  defp record_event({:success, _job, _meta}, %State{success_count: count} = state) do
    %State{state | success_count: count + 1}
  end

  defp record_event({:failure, _job, _error, _stack}, %State{failure_count: count} = state) do
    %State{state | failure_count: count + 1}
  end

  defp record_event(_event, state) do
    state
  end

  defp process_enqueued(%State{failure_count: 0, success_count: 0} = state) do
    state
  end

  defp process_enqueued(%State{client: client} = state) do
    :ok = Client.record_stats(client, failure: state.failure_count, success: state.success_count)

    %{state | failure_count: 0, success_count: 0}
  end

  defp schedule_flush(%State{flush_interval: interval} = state) do
    Process.send_after(self(), :flush, interval)

    state
  end
end
