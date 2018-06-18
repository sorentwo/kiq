defmodule Kiq.Queue.Consumer do
  @moduledoc false

  use ConsumerSupervisor

  alias Kiq.Queue.Runner

  @doc false
  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    ConsumerSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl ConsumerSupervisor
  def init(client: _, reporter: reporter, subscribe_to: subscribe_to) do
    children = [{Runner, [[reporter: reporter]]}]

    ConsumerSupervisor.init(children, strategy: :one_for_one, subscribe_to: subscribe_to)
  end
end
