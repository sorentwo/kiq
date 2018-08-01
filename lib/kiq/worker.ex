defmodule Kiq.Worker do
  @moduledoc """
  Defines a behavior and macro to guide the creation of worker modules.

  Worker modules do the work of processing a job. At a minimum they must define
  a `perform` function, which will be called with the arguments that were
  enqueued with the `Kiq.Job`.

  ## Defining Workers

  Define a worker to process jobs in the `events` queue:

      defmodule MyApp.Workers.Business do
        use Kiq.Worker, queue: "events"

        @impl Kiq.Worker
        def perform(args) do
          IO.inspect(args)
        end
      end

  The `perform/1` function will always receive a list of arguments. In this
  example the worker will simply inspect any arguments that are provided.

  ## Enqueuing Jobs

  All workers implement a `new/1` function that converts a list of arguments
  into a `Kiq.Job` that is suitable for enqueuing:

      ["doing", "business"]
      |> MyApp.Workers.Business.new()
      |> MyApp.Kiq.enqueue()
  """

  alias Kiq.Job

  @type args :: list(any())
  @type opts :: [queue: binary(), retry: boolean()]

  @doc """
  Build a job for this worker using all default options.

  Any additional arguments that are provided will be merged into the job.
  """
  @callback new(args :: args()) :: Job.t()

  @doc """
  The `perform/1` function is called with the enqueued arguments.

  The return value is not important.
  """
  @callback perform(args :: args()) :: any()

  defmacro __using__(opts) do
    opts = Keyword.put_new(opts, :queue, "default")

    quote do
      alias Kiq.Worker

      @behaviour Worker

      @impl Worker
      def new(args) when is_list(args) do
        Worker.new(__MODULE__, args, unquote(opts))
      end

      @impl Worker
      def perform(args) when is_list(args) do
        :ok
      end

      defoverridable new: 1, perform: 1
    end
  end

  @doc false
  @spec new(module(), map() | Keyword.t(), opts()) :: Job.t()
  def new(module, args, opts) do
    opts
    |> Keyword.put(:args, args)
    |> Keyword.put(:class, module)
    |> Job.new()
  end
end
