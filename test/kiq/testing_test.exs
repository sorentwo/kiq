defmodule Kiq.TestingTest do
  use Kiq.Case, async: true

  use Kiq.Testing, client: TestClient

  alias Kiq.Client

  setup do
    config = config(test_mode: :sandbox)

    {:ok, client} = start_supervised({Client, config: config, name: TestClient})

    {:ok, client: client}
  end

  test "job presence is scoped by asserted properties", %{client: client} do
    {:ok, _} = Client.store(client, job(class: "MyWorker", args: [1, 2], queue: "a"))
    {:ok, _} = Client.store(client, job(class: "MyWorker", args: [4, 5], queue: "b"))

    assert_enqueued(queue: "a", class: "MyWorker")
    assert_enqueued(queue: "b", class: "MyWorker", args: [4, 5])

    refute_enqueued(queue: "c", class: "MyWorker", args: [4, 5])
    refute_enqueued(queue: "a", class: "MyWorker", args: [4, 5])
    refute_enqueued(queue: "b", class: "MyWorker", args: [1, 2])

    :ok = stop_supervised(Client)
  end

  test "assertions can be made with :global scoping", %{client: client} do
    fn ->
      {:ok, _} = Client.store(client, job(queue: "a"))
      {:ok, _} = Client.store(client, job(queue: "b"))
    end
    |> Task.async()
    |> Task.await()

    refute_enqueued(queue: "a")
    refute_enqueued(queue: "b")

    assert_enqueued(:shared, queue: "a")
    assert_enqueued(:shared, queue: "b")

    :ok = stop_supervised(Client)
  end
end
