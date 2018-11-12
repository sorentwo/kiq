defmodule Kiq.Reporter.InstrumenterTest do
  use Kiq.Case, async: true

  alias Kiq.Reporter.Instrumenter, as: Reporter

  def attach(type) do
    Telemetry.attach("test-#{type}", [:kiq, :job, type], __MODULE__, :handle_event, nil)
  end

  def handle_event([:kiq, :job, type], value, metadata, _config) do
    send(self(), {type, value, metadata})
  end

  test "job started metrics are reported" do
    attach(:started)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_started(job, nil)

    assert_received {:started, 1, %{class: "Worker", queue: "events"}}
  after
    Telemetry.detach("test-started")
  end

  test "job success metrics are reported" do
    attach(:success)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_success(job, [timing: 123], nil)

    assert_received {:success, 123, %{class: "Worker", queue: "events"}}
  after
    Telemetry.detach("test-success")
  end

  test "job aborted metrics are reported" do
    attach(:aborted)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_aborted(job, [reason: :expired], nil)

    assert_received {:aborted, 1, %{class: "Worker", queue: "events", reason: :expired}}
  after
    Telemetry.detach("test-aborted")
  end

  test "job failure metrics are reported" do
    attach(:failure)

    job = job(class: "Worker", queue: "events")

    Reporter.handle_failure(job, %RuntimeError{}, [], nil)

    assert_received {:failure, 1, %{class: "Worker", queue: "events", error: "RuntimeError"}}
  after
    Telemetry.detach("test-failure")
  end
end
