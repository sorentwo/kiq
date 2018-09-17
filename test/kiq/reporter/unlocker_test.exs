defmodule Kiq.Reporter.UnlockerTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, EchoClient, FakeProducer}
  alias Kiq.Reporter.Unlocker, as: Reporter

  @token "asdfghjklqwertyuiop"

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

  test "started jobs with :unique_until start are unlocked" do
    job = job(unique_token: @token, unique_until: "start")

    :ok = emit_event({:started, job})

    assert_receive {:unlock_job, ^job}
  end

  test "started jobs with any other :unique_until value are ignored" do
    job = job(unique_token: @token, unique_until: "success")

    :ok = emit_event({:started, job})

    refute_receive {:unlock_job, _job}, 200
  end

  test "successful jobs with a unique token are unlocked" do
    job = job(unique_token: @token)

    :ok = emit_event({:success, job, []})

    assert_receive {:unlock_job, unlock_job}

    assert unlock_job.jid == job.jid
    assert unlock_job.unique_until == "success"
  end

  test "successful jobs with an :unique_until start are ignored" do
    job = job(unique_token: @token, unique_until: "start")

    :ok = emit_event({:success, job, []})

    refute_receive {:unlock_job, _job}, 200
  end

  test "successful jobs without a unique token are ignored" do
    job = job()

    :ok = emit_event({:success, job, []})

    refute_receive {:unlock_job, _job}, 200
  end
end
