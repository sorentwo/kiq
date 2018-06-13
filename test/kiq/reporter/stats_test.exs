defmodule Kiq.Reporter.StatsTest do
  use Kiq.Case, async: true

  alias Kiq.{EchoClient, FakeProducer}
  alias Kiq.Reporter.Stats, as: Reporter

  defp emit_event(event) do
    {:ok, cli} = start_supervised({EchoClient, test_pid: self()})
    {:ok, pro} = start_supervised({FakeProducer, events: [event]})
    {:ok, con} = start_supervised({Reporter, client: cli, flush_interval: 5})

    GenStage.sync_subscribe(con, to: pro)

    Process.sleep(10)

    :ok = stop_supervised(Reporter)
    :ok = stop_supervised(FakeProducer)
    :ok = stop_supervised(EchoClient)
  end

  test "stats for successful jobs are recorded" do
    :ok = emit_event({:success, job(), []})

    assert_receive {:record_stats, failure: 0, success: 1}
  end

  test "stats for failed jobs are recorded" do
    :ok = emit_event({:failure, job(), %RuntimeError{}, []})

    assert_receive {:record_stats, failure: 1, success: 0}
  end
end
