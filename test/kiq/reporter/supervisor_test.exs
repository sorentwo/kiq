defmodule Kiq.Reporter.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.EchoClient
  alias Kiq.Reporter.{Logger, Producer, Retryer, Stats}
  alias Kiq.Reporter.Supervisor, as: ReporterSupervisor

  describe "start_link/1" do
    test "producer and consumer children are managed for the queue" do
      {:ok, cli} = start_supervised({EchoClient, []})
      {:ok, sup} = start_supervised({ReporterSupervisor, client: cli, reporter_name: Kiq.Rep})

      children = for {name, _pid, _type, _id} <- Supervisor.which_children(sup), do: name

      assert Stats in children
      assert Retryer in children
      assert Logger in children
      assert Producer in children

      assert Process.whereis(Kiq.Rep)

      :ok = stop_supervised(EchoClient)
      :ok = stop_supervised(ReporterSupervisor)
    end
  end
end
