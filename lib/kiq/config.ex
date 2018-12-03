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
          dead_limit: pos_integer(),
          dead_timeout: pos_integer(),
          elect_ttl: pos_integer(),
          extra_reporters: list(module()),
          fetch_interval: pos_integer(),
          flush_interval: pos_integer(),
          identity: binary(),
          pool_name: name(),
          pool_size: pos_integer(),
          queues: list(queue_config()),
          registry_name: name(),
          reporter_name: name(),
          reporters: list(module()),
          schedulers: list(binary()),
          senator_name: name(),
          server?: boolean(),
          test_mode: :disabled | :sandbox
        }

  defstruct client_name: Client,
            client_opts: [],
            dead_limit: 10_000,
            dead_timeout: 180 * 24 * 60 * 60,
            elect_ttl: 60_000,
            extra_reporters: [],
            fetch_interval: 500,
            flush_interval: 10,
            queues: [default: 25],
            identity: nil,
            pool_name: Pool,
            pool_size: 5,
            registry_name: Registry,
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

    Enum.each(opts, &validate_opt!/1)

    struct!(__MODULE__, opts)
  end

  defp validate_opt!({:pool_size, pool_size}) do
    unless is_integer(pool_size) and pool_size > 0 do
      raise ArgumentError, "expected :pool_size to be an integer greater than 0"
    end
  end

  defp validate_opt!({:queues, queues}) do
    valid_queues? = fn ->
      queues
      |> Keyword.values()
      |> Enum.all?(fn size -> is_integer(size) and size > 0 end)
    end

    unless Keyword.keyword?(queues) and valid_queues?.() do
      raise ArgumentError, "expected :queues to be a keyword list of {atom, integer} pairs"
    end
  end

  defp validate_opt!({key, reporters}) when key in [:extra_reporters, :reporters] do
    valid_reporters? = fn ->
      Enum.all?(reporters, fn reporter ->
        is_atom(reporter) and Code.ensure_loaded?(reporter) and
          function_exported?(reporter, :handle_events, 3)
      end)
    end

    unless is_list(reporters) and valid_reporters?.() do
      raise ArgumentError,
            "expected :reporters to be a list of modules implementing the Kiq.Reporter behaviour"
    end
  end

  defp validate_opt!({:schedulers, schedulers}) do
    valid_schedulers? = fn ->
      Enum.all?(schedulers, fn scheduler -> is_binary(scheduler) or is_atom(scheduler) end)
    end

    unless is_list(schedulers) and valid_schedulers?.() do
      raise ArgumentError, "expected :schedulers to be a list of binaries or atoms"
    end
  end

  defp validate_opt!({:test_mode, test_mode}) do
    unless test_mode in [:disabled, :sandbox] do
      raise ArgumentError, "expected :test_mode to be either :disabled or :sandbox"
    end
  end

  defp validate_opt!(_opt), do: :ok
end
