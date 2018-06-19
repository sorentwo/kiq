defmodule Kiq.Testing do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 2, refute: 2]

  alias Kiq.Client

  @doc false
  def assert_enqueued(client, args) do
    args = Enum.into(args, %{})
    jobs = jobs(client, args)

    assert Enum.member?(jobs, args), """
    expected #{inspect(args)} to be included in #{inspect(jobs)}
    """
  end

  @doc false
  def refute_enqueued(client, args) do
    args = Enum.into(args, %{})
    jobs = jobs(client, args)

    refute Enum.member?(jobs, args), """
    expected #{inspect(args)} not to be included in #{inspect(jobs)}
    """
  end

  # Helpers

  defp jobs(client, args) do
    queue = Map.get(args, :queue, "default")
    keys = Map.keys(args)

    client
    |> Client.jobs(queue)
    |> Enum.map(&Map.take(&1, keys))
  end
end
