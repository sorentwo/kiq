defmodule Kiq.Pool do
  @moduledoc """
  Kiq maintains a fixed pool of Redix connections that are used by processes to
  communicate with Redis.

  The pool is a fixed set of supervised connections. Calling `checkout/1` will
  return a random connection pid. The Redis connection is fully duplexed,
  making it safe for multiple processes to use the same connection
  simultaneously. Connections never need to be checked back in.

  ## Ad-Hoc Usage

  Each supervised Kiq instance will have its own pool. The pool name is derived
  from the module name, i.e. the module `MyApp.Kiq` would have a supervised
  pool registered as `MyApp.Kiq.Pool`. The name can be used to checkout
  connections and execute commands in the console.

  For example, to get a list of the queues that are currently active:

      MyApp.Kiq.Pool
      |> Kiq.Pool.checkout()
      |> Redix.command(["SMEMBERS", "queues"])
  """

  use GenServer

  alias Kiq.Config

  @type options :: [config: Config.t(), name: GenServer.name()]

  defmodule State do
    @moduledoc false

    defstruct [:pool_name, :pool_size]
  end

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get the pid of a supervised Redix connection.

  Connections are randomly allocated and don't need to be checked back in.
  """
  @spec checkout(GenServer.server()) :: pid()
  def checkout(server \\ __MODULE__) do
    GenServer.call(server, :checkout)
  end

  @doc false
  @spec worker_name(binary() | atom(), non_neg_integer()) :: module()
  def worker_name(pool_name, index) do
    Module.concat([pool_name, "N#{index}"])
  end

  # Server

  @impl GenServer
  def init(config: %Config{pool_name: pool_name, pool_size: pool_size}) do
    {:ok, %State{pool_name: pool_name, pool_size: pool_size}}
  end

  @impl GenServer
  def handle_call(:checkout, _from, state) do
    index = rem(System.unique_integer([:positive]), state.pool_size)

    pid =
      state.pool_name
      |> worker_name(index)
      |> Process.whereis()

    {:reply, pid, state}
  end
end
