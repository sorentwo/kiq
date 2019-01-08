defmodule Kiq.RunningJob do
  @moduledoc false

  alias Kiq.{Encoder, Job, Timestamp}

  @type t :: %__MODULE__{key: binary(), encoded: binary()}

  defstruct [:key, :encoded]

  @spec new(job :: Job.t()) :: t()
  def new(%Job{pid: pid, queue: queue} = job) do
    details = %{queue: queue, payload: Job.to_map(job), run_at: Timestamp.unix_now()}

    %__MODULE__{key: format_key(pid), encoded: Encoder.encode(details)}
  end

  defp format_key(pid) when is_pid(pid) or is_reference(pid) do
    to_string(:io_lib.format("~p", [pid]))
  end
end
