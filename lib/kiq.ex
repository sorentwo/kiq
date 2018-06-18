defmodule Kiq do
  @moduledoc """
  Documentation for Kiq.
  """

  def enqueue(job) do
    Kiq.Client.enqueue(Kiq.Client, job)
  end
end
