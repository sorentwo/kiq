defmodule Kiq.Reporter.InstrumenterTest do
  use Kiq.Case, async: true

  alias Kiq.Reporter.Instrumenter, as: Reporter

  def attach(type) do
    :telemetry.attach("test-#{type}", [:kiq, :job, type], &handle_event/4, nil)
  end

  def handle_event([:kiq, :job, type], value, metadata, _config) do
    send(self(), {type, value, metadata})
  end

  test "job started metrics are reported" do
    attach(:started)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_started(job, nil)

    assert_received {:started, %{value: 1}, %{class: "Worker", queue: "events"}}
  after
    :telemetry.detach("test-started")
  end

  test "job success metrics are reported" do
    attach(:success)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_success(job, [timing: 123], nil)

    assert_received {:success, %{timing: 123}, %{class: "Worker", queue: "events"}}
  after
    :telemetry.detach("test-success")
  end

  test "job aborted metrics are reported" do
    attach(:aborted)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_aborted(job, [reason: :expired], nil)

    assert_received {:aborted, %{value: 1}, %{class: "Worker", queue: "events", reason: :expired}}
  after
    :telemetry.detach("test-aborted")
  end

  test "job failure metrics are reported" do
    attach(:failure)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_failure(job, %RuntimeError{}, [], nil)

    assert_received {:failure, %{value: 1},
                     %{class: "Worker", queue: "events", error: "RuntimeError"}}
  after
    :telemetry.detach("test-failure")
  end
end
