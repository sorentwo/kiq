defmodule Kiq.Necromancer do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Pool, Senator}
  alias Kiq.Client.Resurrection

  @typep options :: [config: Config.t(), name: Config.name()]

  defmodule State do
    @moduledoc false

    defstruct [:pool, :senator, interval: 60_000]
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Server

  @impl GenServer
  def init(config: %Config{pool_name: pool, senator_name: senator}) do
    state = %State{pool: pool, senator: senator}

    send(self(), :resurrect)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:resurrect, state) do
    state
    |> perform_resurrect()
    |> schedule_resurrect()

    {:noreply, state}
  end

  # Helper

  defp perform_resurrect(%State{pool: pool, senator: senator} = state) do
    if Senator.leader?(senator) do
      pool
      |> Pool.checkout()
      |> Resurrection.resurrect()
    end

    state
  end

  defp schedule_resurrect(%State{interval: interval} = state) do
    Process.send_after(self(), :resurrect, interval)

    state
  end
end
