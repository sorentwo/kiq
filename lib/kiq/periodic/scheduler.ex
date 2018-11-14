defmodule Kiq.Periodic.Scheduler do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Periodic, Pool, Senator}
  alias Kiq.Client.{Locking, Queueing}

  @typep options :: [config: Config.t(), name: identifier()]

  @lock_key "periodic"
  @lock_ttl 60

  defmodule State do
    @moduledoc false

    defstruct [:identity, :periodics, :pool, :senator, processing_interval: :timer.minutes(1)]
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Callbacks

  @impl GenServer
  def init(config: %Config{} = conf) do
    state = %State{
      identity: conf.identity,
      periodics: conf.periodics,
      pool: conf.pool_name,
      senator: conf.senator_name
    }

    send(self(), :process)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:process, state) do
    schedule_processing(state)

    with true <- Enum.any?(state.periodics),
         true <- Senator.leader?(state.senator),
         conn <- Pool.checkout(state.pool),
         true <- Locking.locked?(conn, @lock_key, state.identity, @lock_ttl) do
      enqueue_periodics(conn, state.periodics)
    end

    {:noreply, state}
  end

  defp schedule_processing(%State{processing_interval: interval} = state) do
    Process.send_after(self(), :process, interval)

    state
  end

  defp enqueue_periodics(conn, periodics) do
    for periodic <- periodics, Periodic.now?(periodic) do
      Queueing.enqueue(conn, Periodic.new_job(periodic))
    end
  end
end
