defmodule Kiq.Worker do
  @moduledoc """
  Defines a behavior and macro to guide the creation of worker modules.

  Worker modules do the work of processing a job. At a minimum they must define
  a `perform` function, which will be called with the arguments that were
  enqueued with the `Kiq.Job`.
  """

  alias Kiq.{Client, Job, Timestamp}

  @type args :: list(any())
  @type opts :: [queue: binary(), retry: boolean()]
  @type client :: GenServer.server()
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
  @callback perform_async(client(), args()) :: on_enqueue()

  @doc """
  Enqueues a job N seconds in the future. The job will be performed on or after
  that time, it isn't an exact guarantee.
  """
  @callback perform_in(client(), seconds(), args()) :: on_enqueue()

  defmacro __using__(opts) do
    opts = Keyword.put_new(opts, :queue, "default")

    quote do
      alias Kiq.Worker

      @behaviour Worker

      @impl Worker
      def perform(args) when is_list(args) do
        :ok
      end

      @impl Worker
      def perform_async(client, args) when is_list(args) do
        Worker.perform_async(client, __MODULE__, args, unquote(opts))
      end

      @impl Worker
      def perform_in(client, seconds, args) when is_integer(seconds) and is_list(args) do
        Worker.perform_in(client, __MODULE__, seconds, args, unquote(opts))
      end

      defoverridable perform: 1, perform_async: 2, perform_in: 3
    end
  end

  @doc false
  @spec perform_async(client(), module(), args(), opts()) :: on_enqueue()
  def perform_async(client, module, args, opts) do
    enqueue(client, %{class: module, args: args}, opts)
  end

  @doc false
  @spec perform_in(client(), module(), seconds(), args(), opts()) :: on_enqueue()
  def perform_in(client, module, seconds, args, opts) do
    enqueue(client, %{class: module, args: args, at: Timestamp.unix_in(seconds)}, opts)
  end

  defp enqueue(client, job_map, opts) do
    job =
      opts
      |> Enum.into(job_map)
      |> Job.new()

    Client.enqueue(client, job)
  end
end
