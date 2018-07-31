defmodule Kiq.Reporter.SupervisorTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, EchoClient, EchoConsumer}
  alias Kiq.Reporter.{Logger, Producer, Retryer, Stats}
  alias Kiq.Reporter.Supervisor, as: ReporterSupervisor

  describe "start_link/1" do
    test "producer and consumer children are managed for the queue" do
      config = Config.new(client_name: Echo, reporter_name: Kiq.Rep)

      {:ok, _ci} = start_supervised({EchoClient, name: Echo})
      {:ok, sup} = start_supervised({ReporterSupervisor, config: config})

      children = for {name, _pid, _type, _id} <- Supervisor.which_children(sup), do: name

      assert Stats in children
      assert Retryer in children
      assert Logger in children
      assert Producer in children

      assert Process.whereis(Kiq.Rep)

      :ok = stop_supervised(EchoClient)
      :ok = stop_supervised(ReporterSupervisor)
    end

    test "extra reporters are also supervised" do
      config =
        Config.new(
          client_name: Echo,
          reporter_name: Kiq.Rep,
          reporters: [],
          extra_reporters: [EchoConsumer]
        )

      {:ok, sup} = start_supervised({ReporterSupervisor, config: config})

      children = for {name, _pid, _type, _id} <- Supervisor.which_children(sup), do: name

      assert EchoConsumer in children
    end
  end
end
