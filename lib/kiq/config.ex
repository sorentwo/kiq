defmodule Kiq.Config do
  @moduledoc false

  @type queue_name :: atom() | binary()
  @type queue_size :: pos_integer()
  @type queue_config :: {queue_name(), queue_size()}

  @type t :: %__MODULE__{
          client: GenServer.server(),
          client_opts: Keyword.t(),
          reporter: GenServer.server(),
          reporters: list(module()),
          schedulers: list(binary()),
          queues: list(queue_config()),
          server?: boolean()
        }

  defstruct client: Kiq.Client,
            client_opts: [],
            reporter: Kiq.Reporter,
            reporters: [Kiq.Reporter.Logger, Kiq.Reporter.Retryer, Kiq.Reporter.Stats],
            schedulers: ~w(retry schedule),
            queues: [default: 25],
            server?: true

  @doc false
  @spec new(map() | Keyword.t()) :: t()
  def new(enum \\ %{}) when is_map(enum) or is_list(enum) do
    opts =
      enum
      |> Enum.into(%{})
      |> Map.put_new(:client_opts, default_client_opts())

    struct!(__MODULE__, opts)
  end

  defp default_client_opts do
    [redis_url: System.get_env("REDIS_URL")]
  end
end
