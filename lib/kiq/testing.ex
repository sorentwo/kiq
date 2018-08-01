defmodule Kiq.Testing do
  @moduledoc """
  This module simplifies testing whether your application is enqueuing jobs as
  expected.

  If your application has defined a top level Kiq module as `MyApp.Kiq`, then
  you would `use` the testing module inside your application's case templates
  like so:

      use Kiq.Testing, client: MyApp.Kiq.Client

  That will define two helper functions, `assert_enqueued/1` and
  `refute_enqueued/1`. The functions can then be used to make assertions on the
  jobs that have been stored while testing.

  Given a simple module that enqueues a job:

      defmodule MyApp.Business do
        alias MyApp.Kiq

        def work(args) do
          Kiq.enqueue(class: "SomeWorker", args: args)
        end
      end

  The behaviour can be exercised in your test code:

      defmodule MyApp.BusinessTest do
        use ExUnit.Case, async: true
        use Kiq.Testing, client: MyApp.Kiq.Client

        alias MyApp.Business

        test "jobs are enqueued with provided arguments" do
          Business.work([1, 2])

          assert_enqueued(class: "SomeWorker", args: [1, 2])
        end
      end
  """

  import ExUnit.Assertions, only: [assert: 2, refute: 2]

  alias Kiq.Client

  @doc false
  defmacro __using__(opts) do
    client = Keyword.fetch!(opts, :client)

    quote do
      import Kiq.Testing

      @doc false
      def assert_enqueued(args) do
        assert_enqueued(unquote(client), args)
      end

      @doc false
      def refute_enqueued(args) do
        refute_enqueued(unquote(client), args)
      end
    end
  end

  @doc """
  Assert that a job with particular options has been enqueued.

  Only values for the provided arguments will be checked. For example, an
  assertion made on `class: "MyWorker"` will match _any_ jobs for that class,
  regardless of the args.

  If the `queue` isn't specified it falls back to `default`. This can cause
  confusion when checking for jobs pushed into alternate queues.
  """
  @spec assert_enqueued(client :: identifier(), args :: Enum.t()) :: any()
  def assert_enqueued(client, args) do
    args = Enum.into(args, %{})
    jobs = jobs(client, args)

    assert Enum.member?(jobs, args), """
    expected #{inspect(args)} to be included in #{inspect(jobs)}
    """
  end

  @doc """
  Refute that a job with particular options has been enqueued.

  See `assert_enqueued/2` for additional details.
  """
  @spec refute_enqueued(client :: identifier(), args :: Enum.t()) :: any()
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
