defmodule Kiq.Queue.Producer do
  @moduledoc false

  use GenStage

  alias Kiq.Config
  alias Kiq.Client.{Pool, Queueing}

  @type options :: [
          config: Config.t(),
          demand: non_neg_integer(),
          poll_interval: non_neg_integer(),
          queue: binary()
        ]

  defmodule State do
    @moduledoc false

    defstruct pool: nil, demand: 0, poll_interval: 1_000, queue: nil
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

    state =
      State
      |> struct(Keyword.put(opts, :pool, conf.pool_name))
      |> schedule_poll()
      |> schedule_resurrect()

    {:producer, state}
  end

  @impl GenStage
  def handle_info(_message, %State{demand: 0} = state) do
    {:noreply, [], state}
  end

  def handle_info(:poll, state) do
    state
    |> schedule_poll()
    |> dispatch()
  end

  def handle_info(:resurrect, %State{pool: pool, queue: queue} = state) do
    pool
    |> Pool.checkout()
    |> Queueing.resurrect(queue)

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_demand(demand, %State{demand: buffered_demand} = state) do
    schedule_poll(state)

    dispatch(%{state | demand: demand + buffered_demand})
  end

  # Helpers

  defp dispatch(%State{pool: pool, demand: demand, queue: queue} = state) do
    jobs =
      pool
      |> Pool.checkout()
      |> Queueing.dequeue(queue, demand)

    {:noreply, jobs, %{state | demand: demand - length(jobs)}}
  end

  defp jitter(interval) do
    trunc(interval / 2 + interval * :rand.uniform())
  end

  defp schedule_poll(%State{poll_interval: interval} = state) do
    Process.send_after(self(), :poll, jitter(interval))

    state
  end

  defp schedule_resurrect(%State{poll_interval: interval} = state) do
    Process.send_after(self(), :resurrect, jitter(interval))

    state
  end
end
