defmodule Kiq.Queue.ProducerTest do
  use Kiq.Case, async: true

  alias Kiq.EchoConsumer, as: Consumer
  alias Kiq.Queue.Producer

  defmodule FakeClient do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:ok, opts}
    end

    def handle_call({:queue_size, _queue}, _from, state) do
      {:reply, length(state[:jobs]), state}
    end

    def handle_call({:dequeue, _queue, size}, _from, state) do
      jobs = Enum.take(state[:jobs], size)
      rest = Enum.drop(state[:jobs], size)

      {:reply, jobs, Keyword.put(state, :jobs, rest)}
    end
  end

  test "jobs are dispatched from the queue when demand is sent" do
    [job_a, job_b, job_c] = jobs = [job(), job(), job()]

    {:ok, pid} = start_supervised({FakeClient, jobs: jobs})
    {:ok, pro} = start_supervised({Producer, client: pid, queue: "special"})
    {:ok, _cn} = start_supervised({Consumer, subscribe_to: [{pro, max_demand: 2}], test_pid: self()})

    assert_receive ^job_a
    assert_receive ^job_b
    assert_receive ^job_c

    :ok = stop_supervised(Consumer)
    :ok = stop_supervised(Producer)
    :ok = stop_supervised(FakeClient)
  end
end
