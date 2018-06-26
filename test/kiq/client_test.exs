defmodule Kiq.ClientTest do
  use Kiq.Case, async: true

  alias Kiq.{Client, Config, Heartbeat, Job, Timestamp}

  @queue "testing"
  @queue_list "queue:#{@queue}"
  @backup_list "queue:#{@queue}:backup"
  @retry_set "retry"
  @schedule_set "schedule"

  setup do
    config = Config.new(client_opts: [redis_url: redis_url()])

    {:ok, client} = start_supervised({Client, config: config})
    {:ok, redis} = start_supervised({Redix, [redis_url()]})

    :ok = Client.clear_all(client)

    {:ok, client: client, redis: redis}
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

  describe "record_heart/2" do
    test "heartbeat process information is updated", %{client: client, redis: redis} do
      running = %{"jid1" => job(), "jid2" => job()}

      %Heartbeat{identity: identity} = heartbeat = Heartbeat.new(running: running)

      assert :ok = Client.record_heart(client, heartbeat)
      assert {:ok, 1} = Redix.command(redis, ["SISMEMBER", "processes", identity])
      assert {:ok, info} = Redix.command(redis, ["HGET", identity, "info"])
      assert {:ok, _beat} = Redix.command(redis, ["HGET", identity, "beat"])
      assert {:ok, "2"} = Redix.command(redis, ["HGET", identity, "busy"])
      assert {:ok, "false"} = Redix.command(redis, ["HGET", identity, "quiet"])
      assert {:ok, 1} = Redix.command(redis, ["EXISTS", "#{identity}:workers"])

      assert %{concurrency: 0} = Jason.decode!(info, keys: :atoms)
    end
  end

  describe "record_stats/2" do
    test "general stat counts are updated", %{client: client, redis: redis} do
      to_int = fn
        nil -> 0
        val -> String.to_integer(val)
      end

      assert {:ok, proc_orig} = Redix.command(redis, ["GET", "stat:processed"])
      assert {:ok, fail_orig} = Redix.command(redis, ["GET", "stat:failed"])
      assert :ok = Client.record_stats(client, failure: 1, success: 2)
      assert {:ok, proc_stat} = Redix.command(redis, ["GET", "stat:processed"])
      assert {:ok, fail_stat} = Redix.command(redis, ["GET", "stat:failed"])

      assert to_int.(proc_stat) - to_int.(proc_orig) == 2
      assert to_int.(fail_stat) - to_int.(fail_orig) == 1
    end
  end
end
