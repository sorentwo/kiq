defmodule Kiq.ClientTest do
  use Kiq.Case, async: true

  @queue "client-test"
  @queue_list "queue:#{@queue}"
  @backup_list "queue:#{@queue}:backup"
  @retry_set "retry"
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
    :ok = Client.clear_set(client, @retry_set)
    :ok = Client.clear_set(client, @schedule_set)

    {:ok, client: client, redis: redis}
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

    test "jobs with a retry count are pushed into the 'retry' set", %{client: client} do
      job = job(at: Timestamp.unix_in(1), retry_count: 1)

      assert {:ok, %Job{}} = Client.enqueue(client, job)

      assert 0 == Client.queue_size(client, @queue)
      assert 1 == Client.set_size(client, @retry_set)
    end
  end

  describe "dequeue/3" do
    test "multiple jobs are returned and pushed into backup", %{client: client, redis: redis} do
      assert {:ok, _job} = Client.enqueue(client, job(args: [1]))
      assert {:ok, _job} = Client.enqueue(client, job(args: [2]))
      assert {:ok, _job} = Client.enqueue(client, job(args: [3]))

      assert [json_a, json_b] = Client.dequeue(client, @queue, 2)

      assert %Job{args: [1]} = Job.decode(json_a)
      assert %Job{args: [2]} = Job.decode(json_b)

      assert {:ok, 1} = Redix.command(redis, ["LLEN", @queue_list])
      assert {:ok, 2} = Redix.command(redis, ["LLEN", @backup_list])
    end
  end

  describe "deschedule/2" do
    test "previously scheduled jobs are enqueued", %{client: client} do
      assert {:ok, _job} = Client.enqueue(client, job(at: Timestamp.unix_in(-1)))
      assert {:ok, _job} = Client.enqueue(client, job(at: Timestamp.unix_in(1)))

      assert :ok = Client.deschedule(client, @schedule_set)

      assert 1 == Client.queue_size(client, @queue)
      assert 1 == Client.set_size(client, @schedule_set)
    end
  end

  describe "resurrect/2" do
    test "backup jobs are restored to their original queue", %{client: client, redis: redis} do
      job_a = job(args: [1])
      job_b = job(args: [2])

      assert {:ok, _res} = Redix.command(redis, ["LPUSH", @backup_list, Job.encode(job_a)])
      assert {:ok, _res} = Redix.command(redis, ["LPUSH", @backup_list, Job.encode(job_b)])

      assert :ok = Client.resurrect(client, @queue)

      assert {:ok, 2} = Redix.command(redis, ["LLEN", @queue_list])
      assert {:ok, 0} = Redix.command(redis, ["LLEN", @backup_list])
    end
  end

  describe "remove_backup/2" do
    test "matching jobs in the backup queue are removed", %{client: client, redis: redis} do
      assert {:ok, job_a} = Client.enqueue(client, job(args: [1]))
      assert {:ok, job_b} = Client.enqueue(client, job(args: [2]))
      assert _jobs = Client.dequeue(client, @queue, 2)

      assert :ok = Client.remove_backup(client, job_a)
      assert {:ok, 1} = Redix.command(redis, ["LLEN", @backup_list])

      assert :ok = Client.remove_backup(client, job_b)
      assert {:ok, 0} = Redix.command(redis, ["LLEN", @backup_list])
    end
  end
end
