defmodule Kiq.Senator do
  @moduledoc false

  use GenServer

  alias Kiq.{Config, Pool, Timestamp}
  alias Kiq.Client.Leadership

  @typep options :: [config: Config.t(), name: GenServer.server()]
  @typep senator :: GenServer.server()

  defmodule State do
    @moduledoc false

    defstruct [:identity, :pool, leader_until: 0, ttl: 60_000]
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec leader?(senator()) :: boolean()
  def leader?(senator) do
    GenServer.call(senator, :leader?)
  end

  # Server

  @impl GenServer
  def init(config: %Config{} = config) do
    Process.flag(:trap_exit, true)

    state =
      %State{identity: config.identity, pool: config.pool_name, ttl: config.elect_ttl}
      |> inauguration()
      |> schedule_election()

    {:ok, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    try do
      state.pool
      |> Pool.checkout()
      |> Leadership.resign(state.identity)
    rescue
      _error -> :ok
    catch
      :exit, _value -> :ok
    end

    :ok
  end

  @impl GenServer
  def handle_info(:elect, %State{} = state) do
    state =
      state
      |> election()
      |> schedule_election()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:leader?, _from, %State{} = state) do
    {:reply, still_leader?(state), state}
  end

  # Helpers

  defp inauguration(%State{} = state) do
    if inaugurate(state) do
      %{state | leader_until: Timestamp.unix_in(state.ttl, :millisecond)}
    else
      %{state | leader_until: 0}
    end
  end

  defp election(%State{} = state) do
    if still_leader?(state) and reelect(state) do
      %{state | leader_until: Timestamp.unix_in(state.ttl, :millisecond)}
    else
      inauguration(state)
    end
  end

  defp schedule_election(state) do
    Process.send_after(self(), :elect, interval(state))

    state
  end

  defp interval(%State{ttl: ttl} = state, leader_boost \\ 4) do
    base = if still_leader?(state), do: div(ttl, leader_boost), else: ttl

    :rand.uniform(base)
  end

  defp inaugurate(state) do
    state.pool
    |> Pool.checkout()
    |> Leadership.inaugurate(state.identity, state.ttl)
  end

  defp reelect(state) do
    state.pool
    |> Pool.checkout()
    |> Leadership.reelect(state.identity, state.ttl)
  end

  defp still_leader?(%State{leader_until: until}), do: until > Timestamp.unix_now()
end
