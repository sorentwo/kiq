defmodule Kiq.ClientTest do
  use Kiq.Case, async: true

  @queue "client-test"
  @queue_list "queue:#{@queue}"
  @backup_list "queue:#{@queue}:backup"
  @schedule_set "schedule"

  defp job(args \\ []) do
    [class: "Worker", queue: @queue]
    |> Keyword.merge(args)
    |> Job.new()
  end

  setup do
    {:ok, client} = Client.start_link(redis_url: redis_url())
    {:ok, redis} = Redix.start_link(redis_url())

    :ok = Client.clear_queue(client, @queue)
    :ok = Client.clear_set(client, @schedule_set)

    {:ok, client: client, redis: redis}
  end

  describe "enqueue/2" do
    test "jobs are enqueued in the configured queue", %{client: client} do
      assert {:ok, %Job{}} = Client.enqueue(client, job())

      assert 1 == Client.queue_size(client, @queue)
      assert 0 == Client.set_size(client, @schedule_set)
    end

    test "scheduled jobs are pushed into the 'schedule' set", %{client: client} do
      job = job(at: Timestamp.unix_in(1))

      assert {:ok, %Job{}} = Client.enqueue(client, job)

      assert 0 == Client.queue_size(client, @queue)
      assert 1 == Client.set_size(client, @schedule_set)
    end
  end

  describe "queue_size/2" do
    test "counting the number of jobs in the queue", %{client: client} do
      assert 0 == Client.queue_size(client, @queue)
      assert {:ok, _job} = Client.enqueue(client, job())
      assert 1 == Client.queue_size(client, @queue)
    end
  end

  describe "set_size/2" do
    test "counting the number of jobs in a set", %{client: client} do
      assert 0 == Client.set_size(client, @schedule_set)
      assert {:ok, _job} = Client.enqueue(client, job(at: Timestamp.unix_in(1)))
      assert 1 == Client.set_size(client, @schedule_set)
    end
  end
end
