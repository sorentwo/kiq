defmodule Kiq.Reporter.Logger do
  @moduledoc false

  require Logger

  use Kiq.Reporter

  alias Kiq.{Job, Reporter}

  # Callbacks

  @impl Reporter
  def handle_started(%Job{class: class, jid: jid, queue: queue}, state) do
    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      status: "started"
    })

    state
  end

  @impl Reporter
  def handle_success(%Job{class: class, jid: jid, queue: queue}, meta, state) do
    timing = Keyword.get(meta, :timing, 0)

    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      timing: "#{timing} µs",
      status: "success"
    })

    state
  end

  @impl Reporter
  def handle_aborted(%Job{class: class, jid: jid, queue: queue}, meta, state) do
    reason = Keyword.get(meta, :reason, :unknown)

    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      reason: reason,
      status: "aborted"
    })

    state
  end

  @impl Reporter
  def handle_failure(%Job{class: class, jid: jid, queue: queue}, error, _stack, state) do
    log_formatted(%{
      worker: class,
      queue: queue,
      jid: jid,
      error: error_name(error),
      status: "failure"
    })

    state
  end

  # Helpers

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
