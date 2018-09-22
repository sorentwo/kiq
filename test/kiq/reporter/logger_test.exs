defmodule Kiq.Reporter.LoggerTest do
  use Kiq.Case, async: true

  import ExUnit.CaptureLog

  alias Kiq.FakeProducer
  alias Kiq.Reporter.Logger, as: Reporter

  setup do
    Logger.flush()

    {:ok, job: job()}
  end

  defp log_event(event) do
    capture_log([colors: [enabled: false]], fn ->
      {:ok, pro} = start_supervised({FakeProducer, events: [event]})
      {:ok, con} = start_supervised({Reporter, []})

      GenStage.sync_subscribe(con, to: pro)

      Process.sleep(10)

      :ok = stop_supervised(Reporter)
      :ok = stop_supervised(FakeProducer)
    end)
  end

  test "job start is logged", %{job: job} do
    message = log_event({:started, job})

    assert message =~ "Worker"
    assert message =~ "testing"
    assert message =~ job.jid
    assert message =~ "started"
  end

  test "job success is logged with timing information", %{job: job} do
    message = log_event({:success, job, [timing: 103]})

    assert message =~ "Worker"
    assert message =~ "testing"
    assert message =~ job.jid
    assert message =~ "103 µs"
    assert message =~ "success"
  end

  test "job abort is logged with the reason", %{job: job} do
    message = log_event({:aborted, job, [reason: :expired]})

    assert message =~ "Worker"
    assert message =~ "expired"
    assert message =~ "aborted"
  end

  test "job failure is logged with exception information", %{job: job} do
    message = log_event({:failure, job, %RuntimeError{}, []})

    assert message =~ "Worker"
    assert message =~ "testing"
    assert message =~ job.jid
    assert message =~ "RuntimeError"
    assert message =~ "failure"
  end
end
