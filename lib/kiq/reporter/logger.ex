defmodule Kiq.Reporter.Logger do
  @moduledoc false

  require Logger

  use GenStage

  alias Kiq.Job

  @behaviour GenStage

  @doc false
  @spec start_link(opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @impl GenStage
  def init(opts) do
    {:consumer, :ok, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events, do: log_event(event)

    {:noreply, [], state}
  end

  # Helpers

  defp log_event({:started, %Job{class: class, jid: jid, queue: queue}}) do
    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      status: "started"
    })
  end

  defp log_event({:success, %Job{class: class, jid: jid, queue: queue}, meta}) do
    timing = Keyword.get(meta, :timing, 0)

    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      timing: "#{timing} µs",
      status: "success"
    })
  end

  defp log_event({:failure, %Job{class: class, jid: jid, queue: queue}, error, _stack}) do
    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      error: error_name(error),
      status: "failure"
    })
  end

  defp log_formatted(payload) do
    Logger.info(fn -> Jason.encode!(payload) end)
  end

  defp error_name(error) do
    %{__struct__: module} = Exception.normalize(:error, error)

    module
    |> Module.split()
    |> Enum.join(".")
  end
end
