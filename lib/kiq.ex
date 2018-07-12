defmodule Kiq do
  @moduledoc false

  alias Kiq.{Client, Job, Timestamp}

  @type job_args :: map() | Keyword.t() | Job.t()
  @type job_opts :: [in: pos_integer(), at: DateTime.t()]

  @doc """
  Starts the client and possibly the supervision tree, returning `{:ok, pid}` when startup is
  successful.

  Returns `{:error, {:already_started, pid}}` if the tree is already started or `{:error, term}`
  in case anything else goes wrong.

  ## Options

  Any options passed to `start_link` will be merged with those provided in the `use` block.
  """
  @callback start_link(opts :: Keyword.t()) :: Supervisor.on_start()

  @doc """
  A callback executed when the supervision tree is started and possibly when configuration is
  read.

  The first argument is the context of the callback being invoked. In most circumstances this
  will be `:supervisor`. The second argument is a keyword list of the combined options passed
  to `use/1` and `start_link/1`.

  Application configuration is _not_ passed into the `init/2` callback. To use application
  config the callback must be overridden and merged manually.
  """
  @callback init(reason :: :supervisor, opts :: Keyword.t()) :: {:ok, Keyword.t()} | :ignore

  @doc """
  Enqueue a job to be processed asynchronously.

  Jobs can be enqueued from `Job` structs, maps or keyword lists.

  ## Options

  * `in` - The amount of time in seconds to wait before processing the job. This must be a
    positive integer.
  * `at` - A specific `DateTime` in the future when the job should be processed.

  ## Examples

      # Enqueue a job to be processed immediately
      MyJob.new([1, 2]) |> MyKiq.enqueue()

      # Enqueue a job in one minute
      MyJob.new([1, 2]) |> MyKiq.enqueue(in: 60)

      # Enqueue a job some time in the future
      MyJob.new([1, 2]) |> MyKiq.enqueue(at: ~D[2020-09-20 12:00:00])

      # Enqueue a job from scratch, without using a worker module
      MyKiq.enqueue(class: "ExternalWorker", args: [1])
  """
  @callback enqueue(job_args(), job_opts()) :: {:ok, Job.t()} | {:error, Exception.t()}

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Kiq

      @client_name Module.concat(__MODULE__, "Client")
      @reporter_name Module.concat(__MODULE__, "Reporter")
      @supervisor_name Module.concat(__MODULE__, "Supervisor")

      @opts unquote(opts)
            |> Keyword.put(:main, __MODULE__)
            |> Keyword.put(:name, @supervisor_name)
            |> Keyword.put(:client_name, @client_name)
            |> Keyword.put(:reporter_name, @reporter_name)

      @doc false
      def child_spec(opts) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}
      end

      @impl Kiq
      def start_link(opts \\ []) do
        @opts
        |> Keyword.merge(opts)
        |> Kiq.Supervisor.start_link()
      end

      @impl Kiq
      def init(reason, opts) when is_atom(reason) and is_list(opts) do
        client_opts = [redis_url: System.get_env("REDIS_URL")]

        {:ok, Keyword.put(opts, :client_opts, client_opts)}
      end

      @impl Kiq
      def enqueue(job_args, job_opts \\ []) when is_map(job_args) or is_list(job_args) do
        Kiq.enqueue(@client_name, job_args, job_opts)
      end

      defoverridable child_spec: 1, init: 2, start_link: 1
    end
  end

  @doc false
  def enqueue(client, job_args, job_opts) do
    job =
      job_args
      |> to_job()
      |> with_opts(job_opts)

    Client.enqueue(client, job)
  end

  defp to_job(%Job{} = job), do: job
  defp to_job(args), do: Job.new(args)

  defp with_opts(job, []), do: job
  defp with_opts(job, at: timestamp), do: %Job{job | at: timestamp}
  defp with_opts(job, in: seconds), do: %Job{job | at: Timestamp.unix_in(seconds)}
end
