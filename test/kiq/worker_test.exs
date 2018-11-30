defmodule Kiq.WorkerTest do
  use ExUnit.Case, async: true

  alias Kiq.{Job, Worker}

  defmodule BasicWorker do
    use Worker
  end

  defmodule CustomWorker do
    use Worker,
      queue: "special",
      retry: 5,
      dead: false,
      expires_in: 100,
      unique_for: 200,
      unique_until: :start,
      unique_token: "thiswillbeignored"

    @impl Worker
    def perform([a, b]) do
      a + b
    end
  end

  describe "new/1" do
    test "workers default to using the 'default' queue" do
      assert %Job{queue: "default"} = BasicWorker.new([])
    end

    test "generating a new job with the stored options" do
      assert %Job{} = job = CustomWorker.new([1, 2])

      assert job.args == [1, 2]
      assert job.class == "Elixir.Kiq.WorkerTest.CustomWorker"
      assert job.queue == "special"
      assert job.retry == 5
      assert job.expires_in == 100
      assert job.unique_for == 200
      assert job.unique_until == "start"
      refute job.dead
      refute job.unique_token
    end
  end

  describe "perform/1" do
    test "a default implementation is provided" do
      assert :ok = BasicWorker.perform([])
    end

    test "the implementation may be overridden" do
      assert 5 == CustomWorker.perform([2, 3])
    end
  end
end
