defmodule Kiq.Integration.RecordingStatsTest do
  use Kiq.Case

  alias Kiq.{Integration, Pool}
  alias Kiq.Client.Introspection

  @identity "ident:1234"

  @moduletag :capture_log

  setup_all do
    start_supervised!({Integration, identity: @identity})

    :ok
  end

  setup do
    :ok = Integration.clear_all()

    {:ok, conn: Pool.checkout(Integration.Pool)}
  end

  test "heartbeat process information is recorded for in-process jobs", %{conn: conn} do
    enqueue_job("SLOW")

    assert_receive :started

    with_backoff(fn ->
      assert Introspection.alive?(conn, @identity)
    end)

    heartbeat = Introspection.heartbeat(conn, @identity)

    assert %{beat: beat, busy: 1, quiet: false} = heartbeat
    assert %{info: %{identity: @identity, queues: ["integration"]}} = heartbeat

    [details] =
      conn
      |> Introspection.workers(@identity)
      |> Map.values()

    assert %{queue: "integration", payload: payload, run_at: _} = details
    assert %{jid: _jid, class: _class, retry: _retry} = payload

    assert_receive :stopped
  end

  test "stats for completed jobs are recorded", %{conn: conn} do
    enqueue_job("PASS")
    enqueue_job("PASS")
    enqueue_job("FAIL")

    assert_receive :failed

    with_backoff(fn ->
      %{processed: new_proc, failed: new_fail} = Introspection.job_stats(conn)

      assert new_proc >= 2
      assert new_fail >= 1
    end)
  end
end
