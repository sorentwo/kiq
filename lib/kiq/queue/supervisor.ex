defmodule Kiq.Queue.Supervisor do
  @moduledoc false

  use Supervisor

  alias Kiq.Queue.{Consumer, Producer}

  @doc false
  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(client: client, queue: queue, limit: limit) do
    producer_name = Module.concat([Kiq, queue, Prod])
    consumer_name = Module.concat([Kiq, queue, Cons])

    children = [
      {Producer, [client: client, queue: queue, name: producer_name]},
      {Consumer, [client: client, subscribe_to: [{producer_name, max_demand: limit}], name: consumer_name]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
