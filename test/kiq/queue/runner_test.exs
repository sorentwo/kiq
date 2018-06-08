defmodule Kiq.Queue.RunnerTest do
  use Kiq.Case, async: true

  alias Kiq.{Job, Worker}
  alias Kiq.Queue.Runner

  defmodule MyWorker do
    use Worker

    def perform(args) do
      [1, 2] = args
    end
  end

  describe "start_link/2" do
    test "executing jobs successfully" do
      assert {:ok, pid} = Runner.start_link([], encoded_job(class: MyWorker))

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end

  describe "run/2" do
    test "successful jobs return timing information" do
      assert {:ok, %Job{}, meta} = Runner.run([], encoded_job(class: MyWorker, args: [1, 2]))
      assert is_integer(meta[:timing])
    end

    test "failed jobs return exception information" do
      assert {:error, %Job{}, error} = Runner.run([], encoded_job(class: MyWorker, args: [1]))
      assert Exception.exception?(error)
    end
  end
end
