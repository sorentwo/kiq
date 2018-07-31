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

defmodule Kiq.Case do
  use ExUnit.CaseTemplate

  alias Kiq.Job

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

  def redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/3"
  end
end
