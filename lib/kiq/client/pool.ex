defmodule Kiq.Client.Pool do
  @moduledoc false

  use GenServer

  alias Kiq.Config

  @type options :: [config: Config.t(), name: GenServer.name()]

  @default_pool_size 5

  defmodule State do
    @moduledoc false

    defstruct [:config, :pool_size]
  end

  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec checkout(GenServer.server()) :: pid()
  def checkout(server \\ __MODULE__) do
    GenServer.call(server, :checkout)
  end

  @spec worker_name(binary() | atom(), non_neg_integer()) :: module()
  def worker_name(pool_name, index) do
    Module.concat([pool_name, "N#{index}"])
  end

  # Server

  @impl GenServer
  def init(config: %Config{client_opts: client_opts} = config) do
    pool_size = Keyword.get(client_opts, :pool_size, @default_pool_size)

    {:ok, %State{config: config, pool_size: pool_size}}
  end

  @impl GenServer
  def handle_call(:checkout, _from, state) do
    index = rem(System.unique_integer([:positive]), state.pool_size)

    pid =
      state.config.pool_name
      |> worker_name(index)
      |> Process.whereis()

    {:reply, pid, state}
  end
end
