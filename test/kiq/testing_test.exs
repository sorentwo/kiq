defmodule Kiq.TestingTest do
  use Kiq.Case, async: true

  import Kiq.Testing, only: [assert_enqueued: 2, refute_enqueued: 2]

  defmodule FakeClient do
    use GenServer

    def start_link(queues: queues) do
      GenServer.start_link(__MODULE__, queues)
    end

    def init(queues) do
      {:ok, queues}
    end

    def handle_call({:jobs, queue}, _from, queues) do
      jobs = Map.get(queues, queue, [])

      {:reply, jobs, queues}
    end
  end

  test "job presence is checked by queue and arguments" do
    jobs_a = [job(class: "MyWorker", args: [1, 2], queue: "a")]
    jobs_b = [job(class: "MyWorker", args: [4, 5], queue: "b")]

    {:ok, client} = start_supervised({FakeClient, queues: %{"a" => jobs_a, "b" => jobs_b}})

    assert_enqueued(client, queue: "a", class: "MyWorker")
    assert_enqueued(client, queue: "b", class: "MyWorker", args: [4, 5])

    refute_enqueued(client, queue: "c", class: "MyWorker", args: [4, 5])
    refute_enqueued(client, queue: "a", class: "MyWorker", args: [4, 5])
    refute_enqueued(client, queue: "b", class: "MyWorker", args: [1, 2])
  end
end
