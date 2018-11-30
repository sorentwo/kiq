defmodule Kiq.Reporter.Logger do
  @moduledoc false

  use Kiq.Reporter

  import Kiq.Logger, only: [log: 1]

  alias Kiq.{Job, Reporter}

  # Callbacks

  @impl Reporter
  def handle_started(%Job{} = job, state) do
    log(%{
      worker: job.class,
      queue: job.queue,
      jid: job.jid,
      status: "started"
    })

    state
  end

  @impl Reporter
  def handle_success(%Job{} = job, meta, state) do
    timing = Keyword.get(meta, :timing, 0)

    log(%{
      worker: job.class,
      queue: job.queue,
      jid: job.jid,
      timing: "#{timing} µs",
      status: "success"
    })

    state
  end

  @impl Reporter
  def handle_aborted(%Job{} = job, meta, state) do
    reason = Keyword.get(meta, :reason, :unknown)

    log(%{
      worker: job.class,
      queue: job.queue,
      jid: job.jid,
      reason: reason,
      status: "aborted"
    })

    state
  end

  @impl Reporter
  def handle_failure(%Job{} = job, error, _stack, state) do
    log(%{
      worker: job.class,
      queue: job.queue,
      jid: job.jid,
      error: error_name(error),
      retry_count: job.retry_count,
      status: "failure"
    })

    state
  end

  # Helpers

  defp error_name(error) do
    %{__struct__: module} = Exception.normalize(:error, error)

    module
    |> Module.split()
    |> Enum.join(".")
  end
end
