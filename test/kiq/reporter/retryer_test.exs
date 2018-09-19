defmodule Kiq.Reporter.RetryerTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, EchoClient, FakeProducer, Job}
  alias Kiq.Reporter.Retryer, as: Reporter

  @error %RuntimeError{message: "bad stuff happened"}

  defp emit_event(event) do
    {:ok, cli} = start_supervised({EchoClient, test_pid: self()})
    {:ok, pro} = start_supervised({FakeProducer, events: [event]})
    {:ok, con} = start_supervised({Reporter, config: %Config{client_name: cli}})

    GenStage.sync_subscribe(con, to: pro)

    Process.sleep(10)

    :ok = stop_supervised(Reporter)
    :ok = stop_supervised(FakeProducer)
    :ok = stop_supervised(EchoClient)
  end

  test "job start is safely ignored" do
    assert :ok = emit_event({:started, job()})
  end

  test "stopped jobs are pruned from the backup queue" do
    job = job()

    :ok = emit_event({:stopped, job})

    assert_receive {:remove_backup, ^job}, 1_000
  end

  test "failed jobs are pushed into the retry set" do
    :ok = emit_event({:failure, job(retry: true, retry_count: 0), @error, []})

    assert_receive {:retry, %Job{} = job}, 1_000

    assert job.retry_count == 1
    assert job.error_class == "RuntimeError"
    assert job.error_message == "bad stuff happened"
  end

  test "jobs are enqueued with a custom retry limit" do
    :ok = emit_event({:failure, job(retry: 6, retry_count: 5), @error, []})

    assert_receive {:retry, %Job{retry: 6, retry_count: 6}}, 1_000
  end

  test "jobs are not enqueued when retries are exhausted" do
    :ok = emit_event({:failure, job(retry: true, retry_count: 25), @error, []})

    refute_receive {:retry, %Job{}}
  end
end
