defmodule Kiq.Job do
  @moduledoc """
  Used to construct a Sidekiq compatible job.

  The job complies with the [Sidekiq Job Format][1], and contains the following
  fields:

  * `jid` - A 12 byte random number as a 24 character hex encoded string
  * `pid` — Process id of the worker running the job, defaults to the calling process
  * `class` - The worker class which is responsible for executing the job
  * `args` - The arguments passed which should be passed to the worker
  * `queue` - The queue where a job should be enqueued, defaults to "default"
  * `retry` - Tells the Kiq worker to retry the enqueue job
  * `retry_count` - The number of times we've retried so far
  * `at` — A time at or after which a scheduled job should be performed, in Unix format
  * `created_at` - When the job was created, in Unix format
  * `enqueue_at` - When the job was enqueued, in Unix format
  * `failed_at` - The first time the job failed, in Unix format
  * `retried_at` — The last time the job was retried, in Unix format
  * `error_message` — The message from the last exception
  * `error_class` — The exception module (or class, in Sidekiq terms)
  * `backtrace` - The number of lines of error backtrace to store, defaults to none
  * `unique_for` - How long uniqueness will be enforced for a job

  [1]: https://github.com/mperham/sidekiq/wiki/Job-Format
  """

  alias Kiq.Timestamp

  @type t :: %__MODULE__{
          jid: binary(),
          pid: pid(),
          class: binary(),
          args: list(any),
          queue: binary(),
          retry: boolean() | non_neg_integer(),
          retry_count: non_neg_integer(),
          at: Timestamp.t(),
          created_at: Timestamp.t(),
          enqueued_at: Timestamp.t(),
          failed_at: Timestamp.t(),
          retried_at: Timestamp.t(),
          error_message: binary(),
          error_class: binary(),
          unique_for: non_neg_integer()
        }

  @enforce_keys ~w(jid class)a
  defstruct jid: nil,
            pid: nil,
            class: nil,
            args: [],
            queue: "default",
            retry: true,
            retry_count: 0,
            at: nil,
            created_at: nil,
            enqueued_at: nil,
            failed_at: nil,
            retried_at: nil,
            error_message: nil,
            error_class: nil,
            unique_for: nil

  @doc """
  Build a new `Job` struct with all dynamic arguments populated.

      iex> Kiq.Job.new(%{class: "Worker"}) |> Map.take([:class, :args, :queue])
      %{class: "Worker", args: [], queue: "default"}

      iex> Kiq.Job.new(module: "Worker") |> Map.get(:class)
      "Worker"
  """
  @spec new(args :: map() | Keyword.t()) :: t()
  def new(%{class: class} = args) do
    args =
      args
      |> Map.put(:class, to_string(class))
      |> Map.put_new(:jid, random_jid())
      |> Map.put_new(:created_at, Timestamp.unix_now())

    struct!(__MODULE__, args)
  end

  def new(%{module: module} = args) do
    args
    |> Map.delete(:module)
    |> Map.put(:class, module)
    |> new()
  end

  def new(args) when is_list(args) do
    args
    |> Enum.into(%{})
    |> new()
  end

  @doc """
  Convert a job into a map suitable for encoding.
  """
  @spec to_map(job :: t()) :: map()
  def to_map(%__MODULE__{} = job) do
    job
    |> Map.from_struct()
    |> Map.drop([:pid])
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.into(%{})
  end

  @doc """
  Encode a job as JSON.

  During the encoding process any keys with `nil` values are removed.
  """
  @spec encode(job :: t()) :: binary()
  def encode(%__MODULE__{} = job) do
    job
    |> to_map()
    |> Jason.encode!()
  end

  @doc """
  Decode an encoded job from JSON into a Job struct.

  All keys are atomized, including keys within arguments. This does _not_ use
  `String.to_existing_atom/1`, so be wary of encoding large maps.

  # Example

      iex> job = Kiq.Job.decode(~s({"class":"MyWorker","args":[1,2]}))
      ...> Map.take(job, [:class, :args])
      %{class: "MyWorker", args: [1, 2]}

      iex> job = Kiq.Job.decode(~s({"class":"MyWorker","args":{"a":1}}))
      ...> Map.get(job, :args)
      %{a: 1}
  """
  @spec decode(input :: binary()) :: t()
  def decode(input) when is_binary(input) do
    input
    |> Jason.decode!(keys: :atoms)
    |> new()
  end

  @doc """
  Generate a compliant, entirely random, job id.

  # Example

      iex> Kiq.Job.random_jid() =~ ~r/^[0-9a-z]{24}$/
      true

      iex> job_a = Kiq.Job.random_jid()
      ...> job_b = Kiq.Job.random_jid()
      ...> job_a == job_b
      false
  """
  @spec random_jid(size :: pos_integer()) :: binary()
  def random_jid(size \\ 12) do
    size
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
