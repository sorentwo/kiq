defmodule Kiq.Reporter.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Config
  alias Kiq.Reporter.{Logger, Producer, Retryer, Stats}

  @type options :: [config: Config.t(), name: identifier()]

  @doc false
  @spec start_link(opts :: options()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    conf = Keyword.get(opts, :config, Config.new())

    Supervisor.start_link(__MODULE__, conf, name: name)
  end

  @impl Supervisor
  def init(%Config{client: client, queues: queues, reporter: reporter}) do
    children = [
      {Producer, name: reporter},
      {Logger, subscribe_to: [reporter]},
      {Retryer, client: client, subscribe_to: [reporter]},
      {Stats, client: client, queues: queues, subscribe_to: [reporter]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
