defmodule Kiq.Queue.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Config
  alias Kiq.Queue.{Consumer, Producer}

  @type options :: [config: Config.t(), queue: binary(), limit: pos_integer(), name: identifier()]

  @doc false
  @spec start_link(opts :: options()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(config: config, queue: queue, limit: limit) do
    prod_name = Module.concat(["Kiq", String.capitalize(queue), "Producer"])
    cons_name = Module.concat(["Kiq", String.capitalize(queue), "Consumer"])
    prod_opts = [client: config.client_name, queue: queue, name: prod_name]

    cons_opts = [
      client: config.client_name,
      reporter: config.reporter_name,
      subscribe_to: [{prod_name, max_demand: limit}],
      name: cons_name
    ]

    children = [{Producer, prod_opts}, {Consumer, cons_opts}]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
