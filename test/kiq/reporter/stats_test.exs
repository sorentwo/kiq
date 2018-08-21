defmodule Kiq.Reporter.StatsTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, EchoClient, FakeProducer, Heartbeat}
  alias Kiq.Reporter.Stats, as: Reporter

  defp emit_event(event) do
    {:ok, cli} = start_supervised({EchoClient, test_pid: self()})
    {:ok, pro} = start_supervised({FakeProducer, events: [event]})
    config = Config.new(client_name: cli, identity: "ident:123")
    {:ok, con} = start_supervised({Reporter, config: config, flush_interval: 5})

    GenStage.sync_subscribe(con, to: pro)

    Process.sleep(10)

    :ok = stop_supervised(Reporter)
    :ok = stop_supervised(FakeProducer)
    :ok = stop_supervised(EchoClient)
  end

  test "stats for in-process jobs are recorded" do
    :ok = emit_event({:started, job()})

    assert_receive {:record_heart, %Heartbeat{identity: "ident:123", busy: 1}}
  end

  test "stats for successful jobs are recorded" do
    :ok = emit_event({:success, job(), []})

    assert_receive {:record_stats, failure: 0, success: 1}
  end

  test "stats for failed jobs are recorded" do
    :ok = emit_event({:failure, job(), %RuntimeError{}, []})

    assert_receive {:record_stats, failure: 1, success: 0}
  end

  test "stats for completed jobs are recorded" do
    :ok = emit_event({:stopped, job()})

    assert_receive {:record_heart, %Heartbeat{identity: "ident:123", busy: 0}}
  end
end
