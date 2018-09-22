defmodule Kiq.Queue.Runner do
  @moduledoc false

  alias Kiq.{Job, Timestamp}
  alias Kiq.Reporter.Producer, as: Reporter

  @type meta :: [timing: pos_integer()]
  @type success :: {:ok, Job.t(), meta()}
  @type aborted :: {:abort, Job.t(), meta()}
  @type failure :: {:error, Job.t(), Exception.t(), list()}
  @type options :: [reporter: identifier()]

  @doc false
  @spec child_spec(args :: Keyword.t()) :: Supervisor.child_spec()
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, args},
      type: :worker,
      restart: :temporary
    }
  end

  @doc false
  @spec start_link(opts :: options(), job_input :: binary()) :: {:ok, pid()}
  def start_link([reporter: reporter], job_input) when is_binary(job_input) do
    Task.start_link(__MODULE__, :run, [reporter, job_input])
  end

  @doc false
  @spec run(reporter :: identifier(), job_input :: binary()) :: success() | aborted() | failure()
  def run(reporter, job_input) do
    job =
      job_input
      |> Job.decode()
      |> Map.replace!(:pid, self())

    try do
      Reporter.started(reporter, job)

      maybe_abort!(job)

      {timing, _return} =
        job
        |> Job.to_module()
        |> :timer.tc(:perform, [job.args])

      Reporter.success(reporter, job, timing: timing)

      {:ok, job, timing: timing}
    rescue
      exception ->
        stacktrace = System.stacktrace()

        Reporter.failure(reporter, job, exception, stacktrace)

        {:error, job, exception, stacktrace}
    catch
      {:abort, :expired} ->
        Reporter.aborted(reporter, job, reason: :expired)

        {:abort, job, reason: :expired}
    after
      Reporter.stopped(reporter, job)
    end
  end

  defp maybe_abort!(%Job{expires_at: expires_at}) when is_float(expires_at) do
    expires_at
    |> Timestamp.from_unix()
    |> DateTime.compare(DateTime.utc_now())
    |> case do
      :lt -> throw({:abort, :expired})
      _cp -> :ok
    end
  end

  defp maybe_abort!(_job), do: :ok
end
