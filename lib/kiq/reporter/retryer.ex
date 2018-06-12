defmodule Kiq.Reporter.Retryer do
  @moduledoc false

  use GenStage

  alias Kiq.{Client, Job, Timestamp}

  @behaviour GenStage

  defmodule State do
    @moduledoc false

    defstruct client: nil, max_retries: 25
  end

  @doc false
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @impl GenStage
  def init(opts) do
    {args, opts} = Keyword.split(opts, [:client, :max_retries])

    {:consumer, struct(State, args), opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events, do: retry_event(event, state)

    {:noreply, [], state}
  end

  # Helpers

  defp retry_event({:success, %Job{} = job, _meta}, %State{client: client}) do
    :ok = Client.remove_backup(client, job)
  end

  defp retry_event({:failure, %Job{retry: true, retry_count: count} = job, error}, %State{
         client: client,
         max_retries: max
       })
       when count < max do
    job =
      job
      |> Map.replace!(:retry_count, count + 1)
      |> Map.replace!(:failed_at, Timestamp.unix_now())
      |> Map.replace!(:retried_at, Timestamp.unix_now())
      |> Map.replace!(:at, retry_at(count))
      |> Map.replace!(:error_class, error_name(error))
      |> Map.replace!(:error_message, Exception.message(error))

    Client.enqueue(client, job)
  end

  defp retry_event(_event, _state) do
    :ok
  end

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
