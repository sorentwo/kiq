defmodule Kiq.ClientTest do
  use Kiq.Case, async: true

  alias Kiq.{Client, Config, Job, Pool, Timestamp}

  @pool_name Module.concat([__MODULE__, "Pool"])
  @queue "testing"
  @queue_list "queue:#{@queue}"
  @backup_list "queue:#{@queue}:backup"
  @schedule_set "schedule"

  setup do
    config =
      Config.new(client_opts: [redis_url: redis_url()], pool_name: @pool_name, pool_size: 1)

    redis_name = Pool.worker_name(@pool_name, 0)

    {:ok, pool} = start_supervised({Pool, config: config, name: @pool_name})
    {:ok, redis} = start_supervised({Redix, {redis_url(), name: redis_name}})
    {:ok, client} = start_supervised({Client, config: config})

    :ok = Client.clear_all(client)

    {:ok, client: client, pool: pool, redis: redis}
  end

  describe "jobs/2" do
    test "fetching all jobs in a queue", %{client: client} do
      assert [] == Client.jobs(client, @queue)
      assert {:ok, job} = Client.enqueue(client, job())
      assert [job] == Client.jobs(client, @queue)
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

  describe "enqueue/2" do
    test "jobs are enqueued in the configured queue", %{client: client} do
      assert {:ok, %Job{} = job} = Client.enqueue(client, job())

      assert job.enqueued_at

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
end
