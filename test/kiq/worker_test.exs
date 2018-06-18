defmodule Kiq.WorkerTest do
  use ExUnit.Case, async: true

  alias Kiq.{Job, Worker, Timestamp}

  defmodule MyClient do
    use GenServer

    def start_link(opts) do
      opts = Keyword.put_new(opts, :test_pid, self())

      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:ok, opts}
    end

    def handle_call({:enqueue, job}, _from, state) do
      {:reply, {:ok, job}, state}
    end

    def handle_call({:enqueue_at, job, _set}, _from, state) do
      {:reply, {:ok, job}, state}
    end
  end

  defmodule MyWorker do
    use Worker, queue: "special", retry: false
  end

  setup do
    {:ok, pid} = start_supervised({MyClient, []})

    {:ok, pid: pid}
  end

  describe "perform/1" do
    test "a default implementation is provided" do
      assert :ok = MyWorker.perform([])
    end
  end

  describe "perform_async/1" do
    test "enqueueing a job for the worker module", %{pid: pid} do
      assert {:ok, %Job{} = job} = MyWorker.perform_async(pid, [1, 2])

      assert job.args == [1, 2]
      assert job.class == to_string(MyWorker)
      assert job.queue == "special"
      refute job.retry
    end
  end

  describe "perform_in/2" do
    test "enqueueing a job in the future", %{pid: pid} do
      assert {:ok, %Job{} = job} = MyWorker.perform_in(pid, 300, [1, 2])

      assert job.args == [1, 2]
      assert job.class == to_string(MyWorker)
      assert job.queue == "special"
      refute job.retry
      refute job.enqueued_at

      assert_in_delta job.at, Timestamp.unix_in(300), 2
    end
  end
end
