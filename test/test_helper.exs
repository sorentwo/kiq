Logger.configure(level: :info)
Logger.configure_backend(:console, format: "$message\n")

ExUnit.start()

defmodule Kiq.EchoClient do
  use GenServer

  def start_link(opts) do
    {name, opts} =
      opts
      |> Keyword.put_new(:test_pid, self())
      |> Keyword.pop(:name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    {:ok, opts}
  end

  def handle_call(message, _from, state) do
    send(state[:test_pid], message)

    {:reply, :ok, state}
  end
end

defmodule Kiq.EchoConsumer do
  use GenStage

  def start_link(opts) do
    {name, opts} =
      opts
      |> Keyword.put_new(:test_pid, self())
      |> Keyword.pop(:name)

    GenStage.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    {args, opts} = Keyword.split(opts, [:config, :test_pid])

    {:consumer, args, opts}
  end

  def handle_events(events, _from, state) do
    test_pid = Keyword.fetch!(state, :test_pid)

    for event <- events, do: send(test_pid, event)

    {:noreply, [], state}
  end
end

defmodule Kiq.FakeProducer do
  use GenStage

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(events: events) do
    {:producer, events}
  end

  def handle_call(_message, from, state) do
    GenStage.reply(from, :ok)

    {:noreply, [], state}
  end

  def handle_demand(_demand, events) do
    {:noreply, events, []}
  end
end

defmodule Kiq.Integration do
  use Kiq, queues: [integration: 3]

  @impl Kiq
  def init(_reason, opts) do
    client_opts = [redis_url: Kiq.Case.redis_url()]

    {:ok, Keyword.put(opts, :client_opts, client_opts)}
  end
end

defmodule Kiq.Integration.Worker do
  use Kiq.Worker, queue: "integration"

  def perform([pid_bin, "FAILING_JOB"]) do
    pid_bin
    |> bin_to_pid()
    |> send({:failed, "FAILING_JOB"})

    raise "forced failing job"
  end

  def perform([pid_bin, value]) do
    pid_bin
    |> bin_to_pid()
    |> send({:processed, value})
  end

  def pid_to_bin(pid \\ self()) do
    pid
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  def bin_to_pid(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end

defmodule Kiq.Case do
  use ExUnit.CaseTemplate

  alias Kiq.{Job, RunningJob}

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def job(args \\ []) do
    [class: "Worker", queue: "testing"]
    |> Keyword.merge(args)
    |> Job.new()
  end

  def encoded_job(args \\ []) do
    args
    |> job()
    |> Job.encode()
  end

  def running_job(args \\ []) do
    args
    |> Keyword.put_new(:pid, make_ref())
    |> job()
    |> RunningJob.new()
  end

  def start_pool(_context) do
    config = Kiq.Config.new(client_opts: [redis_url: redis_url(), pool_size: 1])

    {:ok, _sup} = start_supervised({Kiq.Client.Supervisor, config: config})
    {:ok, _pid} = start_supervised({Kiq.Client.Pool, config: config})

    :ok
  end

  def redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/3"
  end
end
