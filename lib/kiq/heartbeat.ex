defmodule Kiq.Heartbeat do
  @moduledoc false

  import Kiq.Identity, only: [hostname: 0, identity: 0, pid: 0]

  alias Kiq.{Job, RunningJob, Timestamp}

  alias __MODULE__

  @type t :: %__MODULE__{
          busy: non_neg_integer(),
          concurrency: non_neg_integer(),
          hostname: :inet.hostname(),
          identity: binary(),
          labels: list(binary()),
          pid: node(),
          queues: list(binary()),
          quiet: boolean(),
          running: map(),
          started_at: Timestamp.t(),
          tag: binary()
        }

  @derive {Jason.Encoder,
           only: [:concurrency, :hostname, :identity, :labels, :pid, :queues, :started_at, :tag]}

  defstruct busy: 0,
            concurrency: 0,
            hostname: nil,
            identity: nil,
            labels: [],
            pid: nil,
            queues: [],
            quiet: false,
            running: %{},
            started_at: nil,
            tag: ""

  @doc false
  @spec new(args :: map() | Keyword.t()) :: t()
  def new(args) when is_map(args) do
    args =
      args
      |> Map.put(:busy, busy(args))
      |> Map.put(:concurrency, concurrency(args))
      |> Map.put(:queues, queues(args))
      |> Map.put(:started_at, Timestamp.unix_now())
      |> Map.put_new(:hostname, hostname())
      |> Map.put_new(:identity, identity())
      |> Map.put_new(:pid, pid())

    struct!(__MODULE__, args)
  end

  def new(args) when is_list(args) do
    args
    |> Keyword.put_new(:queues, [])
    |> Enum.into(%{})
    |> new()
  end

  @doc false
  @spec add_running(heartbeat :: t(), job :: Job.t()) :: t()
  def add_running(%__MODULE__{running: running} = heartbeat, %Job{jid: jid} = job) do
    running = Map.put_new(running, jid, RunningJob.new(job))

    %{heartbeat | busy: map_size(running), running: running}
  end

  @doc false
  @spec rem_running(heartbeat :: t(), job :: Job.t()) :: t()
  def rem_running(%__MODULE__{running: running} = heartbeat, %Job{jid: jid}) do
    running = Map.delete(running, jid)

    %{heartbeat | busy: map_size(running), running: running}
  end

  ## Helpers

  defp busy(%{running: running}) when is_map(running) do
    map_size(running)
  end

  defp busy(_args) do
    0
  end

  defp concurrency(%{queues: queues}) when is_list(queues) do
    Enum.reduce(queues, 0, fn {_name, size}, sum -> sum + size end)
  end

  defp concurrency(_args) do
    0
  end

  defp queues(%{queues: queues}) when is_list(queues) do
    Enum.map(queues, fn {name, _size} -> to_string(name) end)
  end

  defp queues(_args) do
    []
  end
end
