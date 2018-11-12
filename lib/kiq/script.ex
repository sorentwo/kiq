defmodule Kiq.Script do
  @moduledoc false

  defmodule BootTask do
    @moduledoc false

    use Task

    alias Kiq.{Pool, Script}

    @spec start_link(config: struct()) :: {:ok, pid()}
    def start_link(config: config) do
      Task.start_link(__MODULE__, :run, [config])
    end

    @spec start_link(struct()) :: {:ok, pid()}
    def run(%_{pool_name: pool}) do
      pool
      |> Pool.checkout()
      |> Script.boot()
    end
  end

  import Redix, only: [noreply_command!: 2]

  @typep conn :: GenServer.server()
  @typep name :: binary()

  @spec boot(conn()) :: :ok
  def boot(conn) do
    base()
    |> Path.join("*.lua")
    |> Path.wildcard()
    |> Enum.each(&load(conn, &1))

    :ok
  end

  @spec hash(name()) :: binary()
  def hash(name) do
    path = path(name)
    data = File.read!(path)

    :sha
    |> :crypto.hash(data)
    |> Base.encode16(case: :lower)
  end

  @spec path(name()) :: binary()
  def path(name) do
    Path.join(base(), name <> ".lua")
  end

  defp base do
    :kiq
    |> :code.priv_dir()
    |> Path.join("scripts")
  end

  defp load(conn, path) do
    noreply_command!(conn, ["SCRIPT", "LOAD", File.read!(path)])
  end
end
