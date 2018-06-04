defmodule Kiq.WorkerTest do
  use ExUnit.Case, async: true

  alias Kiq.{Job, Worker, Timestamp}

  defmodule MyWorker do
    use Worker, queue: "special"
  end

  describe "perform/1" do
    test "a default implementation is provided" do
      assert :ok = MyWorker.perform([])
    end
  end

  describe "perform_async/1" do
    test "enqueueing a job for the worker module" do
      assert {:ok, %Job{} = job} = MyWorker.perform_async([1, 2])

      assert job.args == [1, 2]
      assert job.class == to_string(MyWorker)
      assert job.queue == "special"
    end
  end

  describe "perform_in/2" do
    test "enqueueing a job in the future" do
      assert {:ok, %Job{} = job} = MyWorker.perform_in(300, [1, 2])

      assert job.args == [1, 2]
      assert job.class == to_string(MyWorker)
      assert job.queue == "special"
      refute job.enqueued_at

      assert_in_delta job.at, Timestamp.unix_in(300), 2
    end
  end
end
