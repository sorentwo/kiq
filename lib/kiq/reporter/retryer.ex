defmodule Kiq.Reporter.Retryer do
  @moduledoc false

  use GenStage

  alias Kiq.{Client, Config, Job, Timestamp}

  @type options :: [config: Config.t(), name: identifier()]

  @default_max 25

  defmodule State do
    @moduledoc false

    defstruct client: nil
  end

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @impl GenStage
  def init(opts) do
    {%Config{client: client}, opts} = Keyword.pop(opts, :config)

    {:consumer, %State{client: client}, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events, do: retry_event(event, state)

    {:noreply, [], state}
  end

  # Helpers

  defp retry_event({:failure, %Job{retry_count: count} = job, error, _stack}, state) do
    if retryable?(job) do
      job =
        job
        |> Map.replace!(:retry_count, count + 1)
        |> Map.replace!(:failed_at, Timestamp.unix_now())
        |> Map.replace!(:retried_at, Timestamp.unix_now())
        |> Map.replace!(:at, retry_at(count))
        |> Map.replace!(:error_class, error_name(error))
        |> Map.replace!(:error_message, Exception.message(error))

      Client.enqueue(state.client, job)
    end
  end

  defp retry_event({:stopped, %Job{} = job}, %State{client: client}) do
    :ok = Client.remove_backup(client, job)
  end

  defp retry_event(_event, _state) do
    :ok
  end

  defp retryable?(%Job{retry: false}), do: false
  defp retryable?(%Job{retry: true, retry_count: count}), do: count < @default_max
  defp retryable?(%Job{retry: max, retry_count: count}) when is_integer(max), do: count < max

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
