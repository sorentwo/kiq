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
  def init(%Config{reporter_name: producer} = config) do
    %Config{reporters: reporters, extra_reporters: extra_reporters} = config

    children = Enum.map(reporters ++ extra_reporters, &reporter_spec(&1, config))
    children = [{Producer, name: producer} | children]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp reporter_spec(reporter, %Config{reporter_name: producer} = config) do
    {reporter, config: config, subscribe_to: [producer]}
  end
end
