defmodule Kiq.Queue.Runner do
  @moduledoc false

  alias Kiq.Job
  # alias Kiq.Reporter.Supervisor, as: Reporter

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
  @spec start_link(opts :: Keyword.t(), job_input :: binary()) :: {:ok, pid()}
  def start_link(opts, job_input) when is_binary(job_input) do
    Task.start_link(__MODULE__, :run, [opts, job_input])
  end

  @doc false
  @spec run(opts :: Keyword.t(), job_input :: binary()) ::
          {:ok, Job.t(), Keyword.t()} | {:error, Job.t(), Exception.t()}
  def run(_opts, job_input) do
    %Job{class: class, args: args} = job = Job.decode(job_input)

    try do
      # Reporter.started(job)

      {timing, _return} =
        class
        |> String.to_existing_atom()
        |> :timer.tc(:perform, [args])

      # Reporter.success(job, timing: timing)

      {:ok, job, timing: timing}
    rescue
      exception ->
        # Reporter.failure(job, exception)

        {:error, job, exception}
    end
  end
end
