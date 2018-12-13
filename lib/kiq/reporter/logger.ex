defmodule Kiq.Reporter.Logger do
  @moduledoc false

  use Kiq.Reporter

  import Kiq.Logger, only: [log: 1]

  alias Kiq.{Job, Reporter}

  # Callbacks

  @impl Reporter
  def handle_started(%Job{} = job, state) do
    log(%{
      event: "job_started",
      jid: job.jid,
      queue: job.queue,
      worker: job.class
    })

    state
  end

  @impl Reporter
  def handle_success(%Job{} = job, meta, state) do
    timing = Keyword.get(meta, :timing, 0)

    log(%{
      event: "job_success",
      jid: job.jid,
      queue: job.queue,
      timing: "#{timing} µs",
      worker: job.class
    })

    state
  end

  @impl Reporter
  def handle_aborted(%Job{} = job, meta, state) do
    reason = Keyword.get(meta, :reason, :unknown)

    log(%{
      event: "job_aborted",
      jid: job.jid,
      queue: job.queue,
      reason: reason,
      worker: job.class
    })

    state
  end

  @impl Reporter
  def handle_failure(%Job{} = job, error, _stack, state) do
    log(%{
      error: error_name(error),
      event: "job_failure",
      jid: job.jid,
      queue: job.queue,
      retry_count: job.retry_count,
      worker: job.class
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
