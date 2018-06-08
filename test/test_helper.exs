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

ExUnit.start()
