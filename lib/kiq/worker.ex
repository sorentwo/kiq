defmodule Kiq.Worker do
  @moduledoc """
  Defines a behavior and macro to guide the creation of worker modules.

  Worker modules do the work of processing a job. At a minimum they must define
  a `perform` function, which will be called with the arguments that were
  enqueued with the `Kiq.Job`.
  """

  alias Kiq.{Job, Timestamp}

  @type args :: list(any())
  @type seconds :: pos_integer()
  @type on_enqueue() :: {:ok, Job.t()} | {:error, Exception.t()}

  @doc """
  The `perform/1` function is called with the enqueued arguments.
  The return value is not important.
  """
  @callback perform(args()) :: any()

  @doc """
  Enqueues a job to be performed for the worker as soon as possible.
  """
  @callback perform_async(args()) :: on_enqueue()

  @doc """
  Enqueues a job N seconds in the future. The job will be performed on or after
  that time, it isn't an exact guarantee.
  """
  @callback perform_in(seconds(), args()) :: on_enqueue()

  defmacro __using__(opts) do
    opts =
      opts
      |> Keyword.take([:queue])
      |> Enum.into(%{})
      |> Macro.escape()

    quote do
      alias Kiq.Worker

      @behaviour Worker

      @impl Worker
      def perform(args) when is_list(args) do
        :ok
      end

      @impl Worker
      def perform_async(args) when is_list(args) do
        Worker.perform_async(__MODULE__, args, unquote(opts))
      end

      @impl Worker
      def perform_in(seconds, args) when is_integer(seconds) and is_list(args) do
        Worker.perform_in(__MODULE__, seconds, args, unquote(opts))
      end

      defoverridable perform: 1, perform_async: 1, perform_in: 2
    end
  end

  @doc false
  @spec perform_async(module(), args(), map()) :: on_enqueue()
  def perform_async(module, args, config) do
    enqueue(%{class: module, args: args}, config)
  end

  @doc false
  @spec perform_in(module(), seconds(), args(), map()) :: on_enqueue()
  def perform_in(module, seconds, args, config) do
    enqueue(%{class: module, args: args, at: Timestamp.unix_in(seconds)}, config)
  end

  defp enqueue(job_map, %{queue: queue}) do
    job_map
    |> Map.put(:queue, queue)
    |> Job.new()
    |> Kiq.enqueue()
  end
end
