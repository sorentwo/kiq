defmodule Kiq.Reporter.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Client
  alias Kiq.Reporter.{Logger, Producer, Retryer, Stats}

  @doc false
  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    client = Keyword.get(opts, :client, Client)
    producer_name = Keyword.get(opts, :producer_name, Producer)

    children = [
      {Producer, name: producer_name},
      {Logger, subscribe_to: [producer_name]},
      {Retryer, client: client, subscribe_to: [producer_name]},
      {Stats, client: client, subscribe_to: [producer_name]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
