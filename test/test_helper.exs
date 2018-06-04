defmodule Kiq.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)

      alias Kiq.{Client, Job, Timestamp}
    end
  end

  def redis_url do
    System.get_env("REDIS_URL") || "redis://localhost:6379/3"
  end
end

ExUnit.start()
