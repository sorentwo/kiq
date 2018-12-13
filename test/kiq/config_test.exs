defmodule Kiq.ConfigTest do
  use Kiq.Case, async: true

  alias Kiq.{Config, Periodic}

  defmodule FakeWorker do
  end

  defmodule RealWorker do
    use Kiq.Worker
  end

  defmodule FakeReporter do
  end

  defmodule RealReporter do
    use Kiq.Reporter
  end

  describe "new/1" do
    test "default struct values are provided" do
      config = Config.new()

      assert config.client_name
      assert config.pool_name
      assert config.pool_size
      assert config.reporter_name
      assert config.schedulers

      assert config.periodics == []
      assert config.queues == [default: 25]
    end

    test ":periodics are validated as tuples of options" do
      assert_raise ArgumentError, fn -> Config.new(periodics: ["* * * * *"]) end
      assert_raise ArgumentError, fn -> Config.new(periodics: [["* * * * *", FakeWorker]]) end
      assert_raise ArgumentError, fn -> Config.new(periodics: [RealWorker]) end

      assert %Config{} = Config.new(periodics: [{"* * * * *", RealWorker}])
      assert %Config{} = Config.new(periodics: [{"* * * * *", RealWorker, queue: "special"}])
    end

    test ":periodics are converted into Periodic modules" do
      %Config{periodics: periodics} = Config.new(periodics: [{"* * * * *", RealWorker}])
      assert [%Periodic{}] = periodics

      %Config{periodics: periodics} =
        Config.new(periodics: [{"* * * * *", RealWorker, queue: "super"}])

      assert [%Periodic{}] = periodics
    end

    test ":pool_size value is verified as an integer" do
      assert_raise ArgumentError, fn -> Config.new(pool_size: 0) end
      assert_raise ArgumentError, fn -> Config.new(pool_size: 1.1) end

      assert %Config{} = Config.new(pool_size: 1)
    end

    test ":queues are validated as atom, integer pairs" do
      assert_raise ArgumentError, fn -> Config.new(queues: %{default: 25}) end
      assert_raise ArgumentError, fn -> Config.new(queues: [{"default", 25}]) end
      assert_raise ArgumentError, fn -> Config.new(queues: [default: 0]) end
      assert_raise ArgumentError, fn -> Config.new(queues: [default: 3.5]) end

      assert %Config{} = Config.new(queues: [default: 1])
    end

    test ":reporters are validated as reporter compliant modules" do
      assert_raise ArgumentError, fn -> Config.new(reporters: [nil]) end
      assert_raise ArgumentError, fn -> Config.new(reporters: ["FakeModule"]) end
      assert_raise ArgumentError, fn -> Config.new(reporters: [FakeReporter]) end
      assert_raise ArgumentError, fn -> Config.new(extra_reporters: [FakeReporter]) end

      assert %Config{} = Config.new(reporters: [RealReporter])
      assert %Config{} = Config.new(extra_reporters: [RealReporter])
    end

    test ":schedulers are validated as a list of atoms or binaries" do
      assert_raise ArgumentError, fn -> Config.new(schedulers: %{retry: true}) end
      assert_raise ArgumentError, fn -> Config.new(schedulers: [retry: true]) end
      assert_raise ArgumentError, fn -> Config.new(schedulers: ["retry", 1]) end

      assert %Config{} = Config.new(schedulers: ["retry"])
    end

    test ":test_mode values are validated as a particular atom" do
      assert_raise ArgumentError, fn -> Config.new(test_mode: false) end
      assert_raise ArgumentError, fn -> Config.new(test_mode: :special) end

      assert %Config{} = Config.new(test_mode: :sandbox)
    end

    test "an identity value is automatically included" do
      config = Config.new()

      assert config.identity
      assert is_binary(config.identity)
    end

    test "provided values are not overwritten" do
      config = Config.new(client_opts: [special: true], identity: "my.custom.ident")

      assert config.client_opts == [special: true]
      assert config.identity == "my.custom.ident"
    end
  end
end
