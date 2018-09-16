defmodule Kiq.Config do
  @moduledoc false

  import Kiq.Identity, only: [identity: 0]

  alias Kiq.{Client, Reporter}
  alias Kiq.Reporter.{Logger, Retryer, Stats, Unlocker}

  @type queue_name :: atom() | binary()
  @type queue_size :: pos_integer()
  @type queue_config :: {queue_name(), queue_size()}

  @type t :: %__MODULE__{
          client: GenServer.server(),
          client_name: term(),
          client_opts: Keyword.t(),
          extra_reporters: list(module()),
          identity: binary(),
          queues: list(queue_config()),
          reporter_name: term(),
          reporters: list(module()),
          schedulers: list(binary()),
          server?: boolean()
        }

  defstruct client: Client,
            client_name: Client,
            client_opts: [],
            extra_reporters: [],
            queues: [default: 25],
            identity: nil,
            reporter_name: Reporter,
            reporters: [Logger, Retryer, Stats, Unlocker],
            schedulers: ~w(retry schedule),
            server?: true

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
