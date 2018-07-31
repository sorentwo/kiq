defmodule Kiq.Config do
  @moduledoc false

  @type queue_name :: atom() | binary()
  @type queue_size :: pos_integer()
  @type queue_config :: {queue_name(), queue_size()}

  @type t :: %__MODULE__{
          client: GenServer.server(),
          client_name: term(),
          client_opts: Keyword.t(),
          reporter_name: term(),
          reporters: list(module()),
          extra_reporters: list(module()),
          schedulers: list(binary()),
          queues: list(queue_config()),
          server?: boolean()
        }

  defstruct client: Kiq.Client,
            client_name: Kiq.Client,
            client_opts: [],
            reporter_name: Kiq.Reporter,
            reporters: [Kiq.Reporter.Logger, Kiq.Reporter.Retryer, Kiq.Reporter.Stats],
            extra_reporters: [],
            schedulers: ~w(retry schedule),
            queues: [default: 25],
            server?: true

  @doc false
  @spec new(map() | Keyword.t()) :: t()
  def new(opts \\ %{}) when is_map(opts) or is_list(opts) do
    struct!(__MODULE__, opts)
  end
end
