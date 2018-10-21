defmodule Kiq.SenatorTest do
  use Kiq.Case

  alias Kiq.{Pool, Senator}
  alias Kiq.Pool.Supervisor

  @pool Kiq.SenatorTest.Pool

  setup do
    config = config(elect_ttl: 100, pool_name: @pool)

    {:ok, _} = start_supervised({Supervisor, config: config})
    {:ok, _} = start_supervised({Pool, config: config, name: @pool})

    {:ok, config: config}
  end

  test "a single senator is elected as leader", %{config: config} do
    {:ok, sen_a} = start_supervised({Senator, config: config}, id: SenA)
    {:ok, sen_b} = start_supervised({Senator, config: config}, id: SenB)

    assert Senator.leader?(sen_a)
    refute Senator.leader?(sen_b)

    # Sleep long enough for the leader's TTL to expire without a refresh
    Process.sleep(div(config.elect_ttl, 4) + 1)

    assert Senator.leader?(sen_a)
  end

  test "leadership transfers to a follower when the leader terminates", %{config: config} do
    {:ok, _sen_} = start_supervised({Senator, config: config}, id: SenA)
    {:ok, sen_b} = start_supervised({Senator, config: config}, id: SenB)

    :ok = stop_supervised(SenA)

    with_backoff(fn ->
      assert Senator.leader?(sen_b)
    end)
  end

  test "leadership is retained when a follower terminates", %{config: config} do
    {:ok, sen_a} = start_supervised({Senator, config: config}, id: SenA)
    {:ok, _sen_} = start_supervised({Senator, config: config}, id: SenB)

    :ok = stop_supervised(SenB)

    assert Senator.leader?(sen_a)
  end
end
