defmodule Kiq.Queue.RunnerTest do
  use Kiq.Case, async: true

  alias Kiq.Queue.Runner
  alias Kiq.Worker

  defmodule MyWorker do
    use Worker

    def perform(args) do
      [1, 2] = args
    end
  end

  setup do
    {:ok, pid} = start_supervised({Kiq.FakeProducer, events: []})

    {:ok, reporter: pid}
  end

  describe "start_link/2" do
    test "executing jobs successfully", %{reporter: reporter} do
      assert {:ok, pid} = Runner.start_link([reporter: reporter], encoded_job(class: MyWorker))

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end

  describe "run/2" do
    test "successful jobs return timing information", %{reporter: reporter} do
      assert {:ok, job, meta} = Runner.run(reporter, encoded_job(class: MyWorker, args: [1, 2]))

      assert is_pid(job.pid)
      assert is_integer(meta[:timing])
    end

    test "failed jobs return exception information", %{reporter: reporter} do
      assert {:error, job, error, stacktrace} =
               Runner.run(reporter, encoded_job(class: MyWorker, args: [1]))

      assert is_pid(job.pid)
      assert Exception.exception?(error)
      assert is_list(stacktrace)
    end
  end
end
