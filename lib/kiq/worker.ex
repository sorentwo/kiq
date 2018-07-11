defmodule Kiq.Worker do
  @moduledoc """
  Defines a behavior and macro to guide the creation of worker modules.

  Worker modules do the work of processing a job. At a minimum they must define
  a `perform` function, which will be called with the arguments that were
  enqueued with the `Kiq.Job`.
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
