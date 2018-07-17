defmodule Kiq.Reporter.Stats do
  @moduledoc false

  use GenStage

  alias Kiq.{Client, Config, Heartbeat}

  @type options :: [config: Config.t(), flush_interval: non_neg_integer(), name: identifier()]

  defmodule State do
    @moduledoc false

    defstruct client: nil,
              heartbeat: nil,
              queues: [],
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
    {conf, opts} = Keyword.pop(opts, :config)
    {fint, opts} = Keyword.pop(opts, :flush_interval, 1_000)

    Process.flag(:trap_exit, true)

    state =
      State
      |> struct!(client: conf.client, queues: conf.queues, flush_interval: fint)
      |> schedule_flush()

    {:consumer, %State{state | heartbeat: Heartbeat.new(queues: state.queues)}, opts}
  end

  @impl GenStage
  def handle_info(:flush, state) do
    state =
      state
      |> record_heart()
      |> record_stats()
      |> schedule_flush()

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    state = Enum.reduce(events, state, &process_event/2)

    {:noreply, [], state}
  end

  @impl GenStage
  def terminate(_reason, state) do
    # Cleanup is best effort, we do _not_ want to have a messy crash because
    # stats couldn't be recorded.
    try do
      record_stats(state)
      remove_heart(state)
    catch
      :exit, _value -> :ok
    rescue
      _error -> :ok
    end

    :ok
  end

  # Helpers

  defp process_event({:started, job}, %State{heartbeat: heartbeat} = state) do
    %State{state | heartbeat: Heartbeat.add_running(heartbeat, job)}
  end

  defp process_event({:success, _job, _meta}, %State{success_count: count} = state) do
    %State{state | success_count: count + 1}
  end

  defp process_event({:failure, _job, _error, _stack}, %State{failure_count: count} = state) do
    %State{state | failure_count: count + 1}
  end

  defp process_event({:stopped, job}, %State{heartbeat: heartbeat} = state) do
    %State{state | heartbeat: Heartbeat.rem_running(heartbeat, job)}
  end

  defp process_event(_event, state) do
    state
  end

  defp record_heart(%State{client: client, heartbeat: heartbeat} = state) do
    :ok = Client.record_heart(client, heartbeat)

    state
  end

  defp record_stats(%State{failure_count: 0, success_count: 0} = state) do
    state
  end

  defp record_stats(%State{client: client} = state) do
    :ok = Client.record_stats(client, failure: state.failure_count, success: state.success_count)

    %State{state | failure_count: 0, success_count: 0}
  end

  defp remove_heart(%State{client: client, heartbeat: heartbeat} = state) do
    :ok = Client.remove_heart(client, heartbeat)

    state
  end

  defp schedule_flush(%State{flush_interval: interval} = state) do
    Process.send_after(self(), :flush, interval)

    state
  end
end
