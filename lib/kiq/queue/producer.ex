defmodule Kiq.Queue.Producer do
  @moduledoc false

  use GenStage

  alias Kiq.{Config, Pool}
  alias Kiq.Client.Queueing

  @type options :: [
          config: Config.t(),
          demand: non_neg_integer(),
          fetch_interval: pos_integer(),
          queue: binary()
        ]

  defmodule State do
    @moduledoc false

    defstruct [:identity, :pool, :queue, demand: 0, fetch_interval: 500]
  end

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  # Server

  @impl GenStage
  def init(opts) do
    {conf, opts} = Keyword.pop(opts, :config)

    opts =
      opts
      |> Keyword.put(:fetch_interval, conf.fetch_interval)
      |> Keyword.put(:identity, conf.identity)
      |> Keyword.put(:pool, conf.pool_name)

    state = struct(State, opts)

    send(self(), :fetch)

    {:producer, state}
  end

  @impl GenStage
  def handle_info(_message, %State{demand: 0} = state) do
    {:noreply, [], state}
  end

  def handle_info(:fetch, state) do
    state
    |> schedule_fetch()
    |> dispatch()
  end

  @impl GenStage
  def handle_demand(demand, %State{demand: buffered_demand} = state) do
    schedule_fetch(state)

    dispatch(%{state | demand: demand + buffered_demand})
  end

  # Helpers

  defp dispatch(%State{demand: demand} = state) do
    jobs =
      state.pool
      |> Pool.checkout()
      |> Queueing.dequeue(state.queue, state.identity, demand)

    {:noreply, jobs, %{state | demand: demand - length(jobs)}}
  end

  # Jitter the interval by a fixed percentage to ensure that it is always lower
  # than the maximum interval, but has some variance. The variance prevents all
  # of the queues from checking Redis at once and slamming it.
  defp jitter(interval) do
    trunc(interval * 0.8 + interval * 0.2 * :rand.uniform())
  end

  defp schedule_fetch(%State{fetch_interval: interval} = state) do
    Process.send_after(self(), :fetch, jitter(interval))

    state
  end
end
