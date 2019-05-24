defmodule Kiq.Reporter.Instrumenter do
  @moduledoc false

  use Kiq.Reporter

  alias Kiq.Job

  @impl Reporter
  def handle_started(%Job{class: class, queue: queue}, state) do
    :telemetry.execute([:kiq, :job, :started], %{value: 1}, %{class: class, queue: queue})

    state
  end

  @impl Reporter
  def handle_success(%Job{class: class, queue: queue}, meta, state) do
    timing = Keyword.get(meta, :timing, 0)

    :telemetry.execute([:kiq, :job, :success], %{timing: timing}, %{class: class, queue: queue})

    state
  end

  @impl Reporter
  def handle_aborted(%Job{class: class, queue: queue}, meta, state) do
    reason = Keyword.get(meta, :reason, :unknown)

    :telemetry.execute([:kiq, :job, :aborted], %{value: 1}, %{
      class: class,
      queue: queue,
      reason: reason
    })

    state
  end

  @impl Reporter
  def handle_failure(%Job{class: class, queue: queue}, error, _stack, state) do
    :telemetry.execute([:kiq, :job, :failure], %{value: 1}, %{
      class: class,
      queue: queue,
      error: error_name(error)
    })

    state
  end

  defp error_name(error) do
    %{__struct__: module} = Exception.normalize(:error, error)

    module
    |> Module.split()
    |> Enum.join(".")
  end
end
