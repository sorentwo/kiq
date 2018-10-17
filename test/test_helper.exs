# Logger.remove_backend(:console)

ExUnit.start(assert_receive_timeout: 1500, refute_receive_timeout: 1500)

defmodule Kiq.Case do
  use ExUnit.CaseTemplate

  alias Kiq.{Config, Job}

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def config(opts \\ []) do
    opts
    |> Keyword.put_new(:client_opts, redis_url: redis_url())
    |> Config.new()
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

  def enqueue_job(value, opts \\ []) do
    pid_bin = Kiq.Integration.Worker.pid_to_bin()

    [pid_bin, value]
    |> Kiq.Integration.Worker.new()
    |> Map.merge(Map.new(opts))
    |> Kiq.Integration.enqueue()
  end

  def redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/3"
  end

  def with_backoff(opts \\ [], fun) do
    total = Keyword.get(opts, :total, 50)
    sleep = Keyword.get(opts, :sleep, 20)

    with_backoff(fun, 0, total, sleep)
  end

  def with_backoff(fun, count, total, sleep) do
    try do
      fun.()
    rescue
      exception in [ExUnit.AssertionError] ->
        if count < total do
          Process.sleep(sleep)

          with_backoff(fun, count + 1, total, sleep)
        else
          reraise(exception, System.stacktrace())
        end
    end
  end
end
