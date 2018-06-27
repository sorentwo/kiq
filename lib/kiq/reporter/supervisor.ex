defmodule Kiq.Reporter.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Config
  alias Kiq.Reporter.Producer

  @type options :: [config: Config.t(), name: identifier()]

  @doc false
  @spec start_link(opts :: options()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    conf = Keyword.get(opts, :config, Config.new())

    Supervisor.start_link(__MODULE__, conf, name: name)
  end

  @impl Supervisor
  def init(%Config{reporter: producer, reporters: reporters} = config) do
    consumers = for reporter <- reporters, do: reporter_spec(reporter, config)
    children = [{Producer, name: producer} | consumers]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp reporter_spec(reporter, %Config{reporter: producer} = config) do
    {reporter, config: config, subscribe_to: [producer]}
  end
end
