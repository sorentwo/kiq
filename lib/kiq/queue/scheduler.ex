defmodule Kiq.Queue.Scheduler do
  @moduledoc false

  use GenServer

  alias Kiq.Client

  @type options :: [
          client: identifier(),
          name: any(),
          poll_interval: pos_integer(),
          set: binary()
        ]

  defmodule State do
    @moduledoc false

    @enforce_keys [:client, :set]
    defstruct client: nil, poll_interval: 1_000, set: nil
  end

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec random_interval(average :: pos_integer()) :: pos_integer()
  def random_interval(average) do
    trunc(average * :rand.uniform() + average / 2)
  end

  # Callbacks

  @impl GenServer
  def init(opts) do
    state = struct(State, opts)

    schedule_poll(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:poll, %State{client: client, set: set} = state) do
    :ok = Client.deschedule(client, set)

    schedule_poll(state)

    {:noreply, state}
  end

  defp schedule_poll(%State{poll_interval: interval}) do
    Process.send_after(self(), :poll, random_interval(interval))
  end
end
