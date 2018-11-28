defmodule Kiq.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.{Client, Config, Necromancer, Pool, Senator}
  alias Kiq.Pool.Supervisor, as: PoolSupervisor
  alias Kiq.Queue.Scheduler
  alias Kiq.Queue.Supervisor, as: QueueSupervisor
  alias Kiq.Reporter.Supervisor, as: ReporterSupervisor
  alias Kiq.Script.BootTask

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

      Supervisor.init(children, strategy: :one_for_one)
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
    supervisor_name = Module.concat([config.pool_name, "Supervisor"])

    [
      {Registry, keys: :duplicate, name: config.registry_name},
      {PoolSupervisor, config: config, name: supervisor_name},
      {Pool, config: config, name: config.pool_name},
      {Client, config: config, name: config.client_name},
      {BootTask, config: config}
    ]
  end

  defp server_children(%Config{server?: false}) do
    []
  end

  defp server_children(config) do
    schedulers = Enum.map(config.schedulers, &scheduler_spec(&1, config))
    queues = Enum.map(config.queues, &queue_spec(&1, config))

    children = [
      {Senator, config: config, name: config.senator_name},
      {Necromancer, config: config},
      {ReporterSupervisor, config: config}
    ]

    children ++ schedulers ++ queues
  end

  defp scheduler_spec(set, config) do
    name = Module.concat(["Kiq", "Scheduler", String.capitalize(set)])
    opts = [config: config, set: set, name: name]

    Supervisor.child_spec({Scheduler, opts}, id: name)
  end

  defp queue_spec({queue, limit}, config) do
    queue = to_string(queue)
    name = Module.concat(["Kiq", "Queue", String.capitalize(queue)])
    opts = [config: config, queue: queue, limit: limit, name: name]

    Supervisor.child_spec({QueueSupervisor, opts}, id: name)
  end
end
