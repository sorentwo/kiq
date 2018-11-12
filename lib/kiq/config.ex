defmodule Kiq.Config do
  @moduledoc false

  import Kiq.Identity, only: [identity: 0]

  alias Kiq.{Client, Pool, Reporter, Senator}
  alias Kiq.Reporter.{Instrumenter, Logger, Retryer, Stats, Unlocker}

  @type name :: GenServer.server()
  @type queue_name :: atom() | binary()
  @type queue_size :: pos_integer()
  @type queue_config :: {queue_name(), queue_size()}

  @type t :: %__MODULE__{
          client_name: term(),
          client_opts: Keyword.t(),
          elect_ttl: pos_integer(),
          extra_reporters: list(module()),
          fetch_interval: pos_integer(),
          flush_interval: pos_integer(),
          identity: binary(),
          pool_name: name(),
          pool_size: pos_integer(),
          queues: list(queue_config()),
          reporter_name: name(),
          reporters: list(module()),
          schedulers: list(binary()),
          senator_name: name(),
          server?: boolean(),
          test_mode: :disabled | :sandbox
        }

  defstruct client_name: Client,
            client_opts: [],
            elect_ttl: 60_000,
            extra_reporters: [],
            fetch_interval: 500,
            flush_interval: 10,
            queues: [default: 25],
            identity: nil,
            pool_name: Pool,
            pool_size: 5,
            reporter_name: Reporter,
            reporters: [Instrumenter, Logger, Retryer, Stats, Unlocker],
            schedulers: ~w(retry schedule),
            senator_name: Senator,
            server?: true,
            test_mode: :disabled

  @doc false
  @spec new(map() | Keyword.t()) :: t()
  def new(opts \\ %{}) when is_map(opts) or is_list(opts) do
    opts =
      opts
      |> Map.new()
      |> Map.put_new(:identity, identity())

    struct!(__MODULE__, opts)
  end
end
