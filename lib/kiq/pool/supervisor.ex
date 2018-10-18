defmodule Kiq.Pool.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.{Config, Pool}

  @type options :: [config: Config.t(), name: GenServer.name()]

  @resiliency_opts [sync_connect: true, exit_on_disconnection: true]

  @spec start_link(opts :: options()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(config: %Config{client_opts: opts, pool_name: pool_name, pool_size: size}) do
    {host, opts} = Keyword.pop(opts, :redis_url)

    children =
      for index <- 0..(size - 1) do
        name = Pool.worker_name(pool_name, index)

        opts =
          opts
          |> Keyword.put(:name, name)
          |> Keyword.merge(@resiliency_opts)

        Supervisor.child_spec({Redix, {host, opts}}, id: name)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
