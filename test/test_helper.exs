Logger.configure(level: :info)
Logger.configure_backend(:console, format: "$message\n")

ExUnit.start(assert_receive_timeout: 1500, refute_receive_timeout: 1500)

defmodule Kiq.Case do
  use ExUnit.CaseTemplate

  import ExUnit.CaptureLog

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

  def capture_integration(opts \\ [], fun) do
    start_supervised!({Kiq.Integration, opts})

    :ok = Kiq.Integration.clear_all()

    logged = capture_log([colors: [enabled: false]], fun)

    :ok = stop_supervised(Kiq.Integration)

    logged
  end

  def with_backoff(opts \\ [], fun) do
    with_backoff(fun, 0, Keyword.get(opts, :total, 20))
  end

  def with_backoff(fun, count, total) do
    try do
      fun.()
    rescue
      exception in [ExUnit.AssertionError] ->
        if count < total do
          Process.sleep(50)

          with_backoff(fun, count + 1, total)
        else
          reraise(exception, __STACKTRACE__)
        end
    end
  end
end
