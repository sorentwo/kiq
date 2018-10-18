defmodule Kiq.Testing do
  @moduledoc """
  This module simplifies making assertions about enqueued jobs during testing.

  Testing assertions only work when Kiq is started with `test_mode` set to
  `:sandbox`. In sandbox mode jobs are never flushed to Redis and are stored in
  memory until the test run is over. Each enqueued job is associated with the
  process that enqueued it, allowing asynchronous tests to check stored jobs
  without any interference.

  ## Using in Tests

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

  ## Testing Jobs From Other Processes

  All calls to `assert_enqueued/3` and `refute_enqueued/3` use the `:sandbox`
  scope by default. That scope ensures that the current process can only find
  its own enqueued jobs. Sometimes this behavior is undesirable. For example,
  when jobs are being enqueued outside of the test process. If a separate
  server or task enqueue a job you may use the `:shared` scoping to make global
  assertions.

      Task.async(fn -> Kiq.enqueue(class: "MyWorker", args: [1, 2]) end)

      assert_enqueued(:shared, class: "MyWorker")
  """

  import ExUnit.Assertions, only: [assert: 2, refute: 2]

  alias Kiq.Client

  @doc false
  defmacro __using__(opts) do
    client = Keyword.fetch!(opts, :client)

    quote do
      alias Kiq.Testing

      @doc false
      def assert_enqueued(scoping \\ :sandbox, args) do
        Testing.assert_enqueued(unquote(client), scoping, args)
      end

      @doc false
      def refute_enqueued(scoping \\ :sandbox, args) do
        Testing.refute_enqueued(unquote(client), scoping, args)
      end
    end
  end

  @doc """
  Assert that a job with particular options has been enqueued.

  Only values for the provided arguments will be checked. For example, an
  assertion made on `class: "MyWorker"` will match _any_ jobs for that class,
  regardless of the args.
  """
  @spec assert_enqueued(client :: identifier(), scoping :: atom(), args :: Enum.t()) :: any()
  def assert_enqueued(client, scoping \\ :sandbox, args) do
    args = Enum.into(args, %{})
    jobs = jobs(client, args, scoping)

    assert Enum.member?(jobs, args), """
    expected #{inspect(args)} to be included in #{inspect(jobs)}
    """
  end

  @doc """
  Refute that a job with particular options has been enqueued.

  See `assert_enqueued/2` for additional details.
  """
  @spec refute_enqueued(client :: identifier(), scoping :: atom(), args :: Enum.t()) :: any()
  def refute_enqueued(client, scoping \\ :sandbox, args) do
    args = Enum.into(args, %{})
    jobs = jobs(client, args, scoping)

    refute Enum.member?(jobs, args), """
    expected #{inspect(args)} not to be included in #{inspect(jobs)}
    """
  end

  # Helpers

  defp jobs(client, args, scoping) do
    keys = Map.keys(args)

    client
    |> Client.fetch(scoping)
    |> Enum.map(&Map.take(&1, keys))
  end
end
