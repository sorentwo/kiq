defmodule Kiq.Reporter.Producer do
  @moduledoc false

  use GenStage

  alias Kiq.Job

  @type server :: GenServer.server()

  defmodule State do
    @moduledoc false

    defstruct demand: 0, queue: :queue.new()
  end

  @doc false
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  @spec started(server(), Job.t()) :: :ok
  def started(server, %Job{} = job) do
    GenStage.call(server, {:notify, {:started, job}})
  end

  @doc false
  @spec success(server(), Job.t(), Keyword.t()) :: :ok
  def success(server, %Job{} = job, meta) when is_list(meta) do
    GenStage.call(server, {:notify, {:success, job, meta}})
  end

  @doc false
  @spec failure(server(), Job.t(), Exception.t(), list()) :: :ok
  def failure(server, %Job{} = job, %{__exception__: true} = error, stacktrace)
      when is_list(stacktrace) do
    GenStage.call(server, {:notify, {:failure, job, error, stacktrace}})
  end

  @doc false
  @spec stopped(server(), Job.t()) :: :ok
  def stopped(server, %Job{} = job) do
    GenStage.call(server, {:notify, {:stopped, job}})
  end

  # Server

  @impl GenStage
  def init(_opts) do
    {:producer, %State{}, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  def handle_call({:notify, event}, from, %State{queue: queue} = state) do
    queue = :queue.in({from, event}, queue)

    dispatch([], %State{state | queue: queue})
  end

  @impl GenStage
  def handle_demand(incoming_demand, %State{demand: buffered_demand} = state) do
    dispatch([], %State{state | demand: incoming_demand + buffered_demand})
  end

  # Helpers

  defp dispatch(events, %State{demand: 0} = state) do
    {:noreply, Enum.reverse(events), state}
  end

  defp dispatch(events, %State{demand: demand, queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, {from, event}}, queue} ->
        GenStage.reply(from, :ok)

        dispatch([event | events], %State{state | queue: queue, demand: demand - 1})

      {:empty, queue} ->
        {:noreply, Enum.reverse(events), %State{state | queue: queue}}
    end
  end
end
