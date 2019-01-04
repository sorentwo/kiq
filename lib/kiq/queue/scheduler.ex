defmodule Kiq.Queue.Scheduler do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Pool}
  alias Kiq.Client.Queueing

  @typep options :: [
           config: Config.t(),
           name: identifier(),
           fetch_interval: pos_integer(),
           set: binary()
         ]

  defmodule State do
    @moduledoc false

    defstruct [:pool, :set, fetch_interval: 1_000]
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec random_interval(pos_integer(), pos_integer()) :: pos_integer()
  def random_interval(average, jitter \\ 10) do
    weight = 1.0 - (jitter / 2 - :rand.uniform(jitter)) / 100.0

    trunc(average * weight)
  end

  # Callbacks

  @impl GenServer
  def init(opts) do
    {conf, opts} = Keyword.pop(opts, :config)

    opts =
      opts
      |> Keyword.put(:pool, conf.pool_name)
      |> Keyword.put(:fetch_interval, conf.fetch_interval)

    state =
      State
      |> struct(opts)
      |> schedule_poll()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:poll, %State{pool: pool, set: set} = state) do
    pool
    |> Pool.checkout()
    |> Queueing.deschedule(set)

    schedule_poll(state)

    {:noreply, state}
  end

  defp schedule_poll(%State{fetch_interval: interval} = state) do
    Process.send_after(self(), :poll, random_interval(interval))

    state
  end
end
