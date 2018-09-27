defmodule Kiq.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Config
  alias Kiq.Client.Pool
  alias Kiq.Client.Supervisor, as: ClientSupervisor
  alias Kiq.Queue.Scheduler
  alias Kiq.Queue.Supervisor, as: QueueSupervisor
  alias Kiq.Reporter.Supervisor, as: ReporterSupervisor

  @doc false
  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    with {:ok, opts} <- init_config(opts) do
      config = Config.new(opts)
      children = client_children(config) ++ server_children(config)

      Supervisor.init(children, strategy: :rest_for_one)
    end
  end

  @doc false
  @spec init_config(Keyword.t()) :: {atom(), Keyword.t()}
  def init_config(opts) do
    {main, opts} = Keyword.pop(opts, :main)

    if main && function_exported?(main, :init, 2) do
      apply(main, :init, [:supervisor, opts])
    else
      {:ok, opts}
    end
  end

  ## Helpers

  defp client_children(config) do
    [
      {ClientSupervisor, config: config},
      {Pool, config: config, name: config.pool_name},
      {config.client, config: config, name: config.client_name}
    ]
  end

  defp server_children(%Config{server?: false}) do
    []
  end

  defp server_children(config) do
    reporters = [{ReporterSupervisor, config: config}]
    schedulers = Enum.map(config.schedulers, &scheduler_spec(&1, config))
    queues = Enum.map(config.queues, &queue_spec(&1, config))

    reporters ++ schedulers ++ queues
  end

  defp scheduler_spec(set, config) do
    name = Module.concat(["Kiq", "Scheduler", String.capitalize(set)])
    opts = [client: config.client_name, set: set, name: name]

    Supervisor.child_spec({Scheduler, opts}, id: name)
  end

  defp queue_spec({queue, limit}, config) do
    queue = maybe_to_string(queue)
    name = Module.concat(["Kiq", "Queue", String.capitalize(queue)])
    opts = [config: config, queue: queue, limit: limit, name: name]

    Supervisor.child_spec({QueueSupervisor, opts}, id: name)
  end

  defp maybe_to_string(queue) when is_atom(queue), do: Atom.to_string(queue)
  defp maybe_to_string(queue) when is_binary(queue), do: queue
end
