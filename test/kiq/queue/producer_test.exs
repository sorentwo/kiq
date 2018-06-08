defmodule Kiq.Queue.ProducerTest do
  use Kiq.Case, async: true

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

  defmodule FakeConsumer do
    use GenStage

    def start_link(opts) do
      GenStage.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:consumer, opts}
    end

    def handle_events(events, _from, state) do
      for event <- events, do: send state[:test_pid], {:job, event}

      {:noreply, [], state}
    end
  end

  test "jobs are dispatched from the queue when demand is sent" do
    [job_a, job_b, job_c] = jobs = [job(), job(), job()]

    {:ok, pid} = start_supervised({FakeClient, jobs: jobs})
    {:ok, pro} = start_supervised({Producer, client: pid, queue: "special"})
    {:ok, con} = start_supervised({FakeConsumer, test_pid: self()})

    GenStage.sync_subscribe(con, to: pro, max_demand: 2)

    assert_receive {:job, ^job_a}
    assert_receive {:job, ^job_b}
    assert_receive {:job, ^job_c}

    :ok = stop_supervised(FakeConsumer)
    :ok = stop_supervised(Producer)
    :ok = stop_supervised(FakeClient)
  end
end
