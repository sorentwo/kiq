defmodule Kiq.Reporter.Instrumenter do
  @moduledoc false

  use Kiq.Reporter

  import Telemetry, only: [execute: 3]

  alias Kiq.Job

  @impl Reporter
  def handle_started(%Job{class: class, queue: queue}, state) do
    execute([:kiq, :job, :started], 1, %{class: class, queue: queue})

    state
  end

  @impl Reporter
  def handle_success(%Job{class: class, queue: queue}, meta, state) do
    timing = Keyword.get(meta, :timing, 0)

    execute([:kiq, :job, :success], timing, %{class: class, queue: queue})

    state
  end

  @impl Reporter
  def handle_aborted(%Job{class: class, queue: queue}, meta, state) do
    reason = Keyword.get(meta, :reason, :unknown)

    execute([:kiq, :job, :aborted], 1, %{class: class, queue: queue, reason: reason})

    state
  end

  @impl Reporter
  def handle_failure(%Job{class: class, queue: queue}, error, _stack, state) do
    execute([:kiq, :job, :failure], 1, %{class: class, queue: queue, error: error_name(error)})

    state
  end

  defp error_name(error) do
    %{__struct__: module} = Exception.normalize(:error, error)

    module
    |> Module.split()
    |> Enum.join(".")
  end
end
