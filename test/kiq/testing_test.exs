defmodule Kiq.TestingTest do
  use Kiq.Case, async: true

  use Kiq.Testing, client: Kiq.TestingTest.Client

  alias Kiq.Client

  test "job presence is checked by queue and arguments" do
    job_a = job(class: "MyWorker", args: [1, 2], queue: "a")
    job_b = job(class: "MyWorker", args: [4, 5], queue: "b")

    {:ok, client} = start_supervised({Client, config: config(flush_interval: 1_000), name: Kiq.TestingTest.Client})

    {:ok, _} = Client.store(client, job_a)
    {:ok, _} = Client.store(client, job_b)

    assert_enqueued(queue: "a", class: "MyWorker")
    assert_enqueued(queue: "b", class: "MyWorker", args: [4, 5])

    refute_enqueued(queue: "c", class: "MyWorker", args: [4, 5])
    refute_enqueued(queue: "a", class: "MyWorker", args: [4, 5])
    refute_enqueued(queue: "b", class: "MyWorker", args: [1, 2])

    :ok = stop_supervised(Client)
  end
end
