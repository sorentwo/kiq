defmodule Kiq.Reporter.Stats do
  @moduledoc false

  use Kiq.Reporter

  alias Kiq.{Heartbeat, Reporter}
  alias Kiq.Client.{Pool, Stats}

  defmodule State do
    @moduledoc false

    defstruct pool: nil,
              heartbeat: nil,
              queues: [],
              success_count: 0,
              failure_count: 0,
              flush_interval: 1_000
  end

  @impl GenStage
  def init(opts) do
    {conf, opts} = Keyword.pop(opts, :config)
    {fint, opts} = Keyword.pop(opts, :flush_interval, 1_000)

    Process.flag(:trap_exit, true)

    state =
      State
      |> struct!(pool: conf.pool_name, queues: conf.queues, flush_interval: fint)
      |> schedule_flush()

    heartbeat = Heartbeat.new(queues: state.queues, identity: conf.identity)

    {:consumer, %State{state | heartbeat: heartbeat}, opts}
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
  def terminate(_reason, state) do
    # Cleanup is best effort, we do _not_ want to have a messy crash because
    # stats couldn't be recorded.
    try do
      record_stats(state)
      remove_heart(state)
    rescue
      _error -> :ok
    catch
      :exit, _value -> :ok
    end

    :ok
  end

  @impl Reporter
  def handle_started(job, %State{heartbeat: heartbeat} = state) do
    %State{state | heartbeat: Heartbeat.add_running(heartbeat, job)}
  end

  @impl Reporter
  def handle_success(_job, _meta, %State{success_count: count} = state) do
    %State{state | success_count: count + 1}
  end

  @impl Reporter
  def handle_failure(_job, _error, _stack, %State{failure_count: count} = state) do
    %State{state | failure_count: count + 1}
  end

  @impl Reporter
  def handle_stopped(job, %State{heartbeat: heartbeat} = state) do
    %State{state | heartbeat: Heartbeat.rem_running(heartbeat, job)}
  end

  # Helpers

  defp record_heart(%State{pool: pool, heartbeat: heartbeat} = state) do
    pool
    |> Pool.checkout()
    |> Stats.record_heart(heartbeat)

    state
  end

  defp record_stats(%State{failure_count: 0, success_count: 0} = state) do
    state
  end

  defp record_stats(%State{pool: pool} = state) do
    pool
    |> Pool.checkout()
    |> Stats.record_stats(failure: state.failure_count, success: state.success_count)

    %State{state | failure_count: 0, success_count: 0}
  end

  defp remove_heart(%State{pool: pool, heartbeat: heartbeat} = state) do
    pool
    |> Pool.checkout()
    |> Stats.remove_heart(heartbeat)

    state
  end

  defp schedule_flush(%State{flush_interval: interval} = state) do
    Process.send_after(self(), :flush, interval)

    state
  end
end
