defmodule Kiq.Periodic do
  @moduledoc false

  alias Kiq.Job
  alias Kiq.Periodic.Crontab

  @type t :: %__MODULE__{crontab: Crontab.t(), worker: module(), options: Keyword.t()}

  @enforce_keys [:crontab, :worker]
  defstruct [:crontab, :worker, options: []]

  @spec new({binary(), module()} | {binary(), module(), Keyword.t()}) :: t()
  def new({expressions, worker}) when is_binary(expressions) and is_atom(worker) do
    new({expressions, worker, []})
  end

  def new({expressions, worker, options}) do
    crontab = Crontab.parse!(expressions)

    struct!(__MODULE__, crontab: crontab, worker: worker, options: options)
  end

  @spec now?(t()) :: boolean()
  def now?(%__MODULE__{crontab: crontab}) do
    Crontab.now?(crontab)
  end

  @spec new_job(t()) :: Job.t()
  def new_job(%__MODULE__{worker: worker, options: options}) do
    worker.new(options[:args] || [])
  end
end
