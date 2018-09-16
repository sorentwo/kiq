defmodule Kiq.Reporter.UnlockerTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, EchoClient, FakeProducer}
  alias Kiq.Reporter.Unlocker, as: Reporter

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

  test "successful jobs with a unique token are unlocked" do
    job = job(unique_token: "asdfghjklqwertyuiop")

    :ok = emit_event({:success, job, []})

    assert_receive {:unlock_job, ^job}
  end

  test "successful jobs without a unique token are ignored" do
    job = job()

    :ok = emit_event({:success, job, []})

    refute_receive {:unlock_job, _job}
  end
end
