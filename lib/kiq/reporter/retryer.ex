defmodule Kiq.Reporter.Retryer do
  @moduledoc false

  use Kiq.Reporter

  alias Kiq.{Job, Pool, Reporter, Timestamp}
  alias Kiq.Client.{Cleanup, Queueing}

  @default_max 25

  defmodule State do
    @moduledoc false

    defstruct [:dead_limit, :dead_timeout, :identity, :pool]
  end

  # Callbacks

  @impl GenStage
  def init(opts) do
    {conf, opts} = Keyword.pop(opts, :config)

    state = %State{
      dead_limit: conf.dead_limit,
      dead_timeout: conf.dead_timeout,
      identity: conf.identity,
      pool: conf.pool_name
    }

    {:consumer, state, opts}
  end

  @impl Reporter
  def handle_failure(%Job{retry_count: count} = job, error, _stack, state) do
    conn = Pool.checkout(state.pool)

    cond do
      retryable?(job) ->
        job =
          job
          |> Map.replace!(:retry_count, count + 1)
          |> Map.replace!(:failed_at, Timestamp.unix_now())
          |> Map.replace!(:retried_at, Timestamp.unix_now())
          |> Map.replace!(:at, retry_at(count))
          |> Map.replace!(:error_class, error_name(error))
          |> Map.replace!(:error_message, Exception.message(error))

        Queueing.retry(conn, job)

      killable?(job) ->
        Cleanup.kill(conn, job, limit: state.dead_limit, timeout: state.dead_timeout)

      true ->
        :ok
    end

    state
  end

  @impl Reporter
  def handle_stopped(%Job{} = job, state) do
    state.pool
    |> Pool.checkout()
    |> Cleanup.remove_backup(state.identity, job)

    state
  end

  # Helpers

  defp retryable?(%Job{retry: false}), do: false
  defp retryable?(%Job{retry: true, retry_count: count}), do: count < @default_max
  defp retryable?(%Job{retry: max, retry_count: count}) when is_integer(max), do: count < max

  defp killable?(%Job{retry: false}), do: false
  defp killable?(%Job{dead: false}), do: false
  defp killable?(%Job{} = job), do: not retryable?(job)

  defp backoff_offset(count, base_value \\ 15, rand_range \\ 30) do
    trunc(:math.pow(count, 4) + base_value + (:rand.uniform(rand_range) + (count + 1)))
  end

  defp error_name(error) do
    %{__struct__: module} = Exception.normalize(:error, error)

    module
    |> Module.split()
    |> Enum.join(".")
  end

  defp retry_at(count) do
    count
    |> backoff_offset()
    |> Timestamp.unix_in()
  end
end
