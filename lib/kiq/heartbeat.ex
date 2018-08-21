defmodule Kiq.Heartbeat do
  @moduledoc false

  import Kiq.Identity, only: [hostname: 0, identity: 0, pid: 0]

  alias Kiq.{Job, Timestamp}

  alias __MODULE__

  @type t :: %__MODULE__{
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

  defstruct busy: 0,
            concurrency: 0,
            identity: nil,
            hostname: nil,
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

    struct!(Heartbeat, args)
  end

  def new(args) when is_list(args) do
    args
    |> Keyword.put_new(:queues, [])
    |> Enum.into(%{})
    |> new()
  end

  @doc false
  @spec add_running(heartbeat :: t(), job :: Job.t()) :: t()
  def add_running(%Heartbeat{running: running} = heartbeat, %Job{jid: jid} = job) do
    running = Map.put_new(running, jid, job)

    %Heartbeat{heartbeat | busy: map_size(running), running: running}
  end

  @doc false
  @spec rem_running(heartbeat :: t(), job :: Job.t()) :: t()
  def rem_running(%Heartbeat{running: running} = heartbeat, %Job{jid: jid}) do
    running = Map.delete(running, jid)

    %Heartbeat{heartbeat | busy: map_size(running), running: running}
  end

  @doc false
  @spec encode(heartbeat :: t()) :: binary()
  def encode(%Heartbeat{} = heartbeat) do
    heartbeat
    |> Map.take([:concurrency, :hostname, :identity, :labels, :pid, :queues, :started_at, :tag])
    |> Jason.encode!()
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
