defmodule Kiq.ConfigTest do
  use Kiq.Case, async: true

  alias Kiq.Config

  describe "new/1" do
    test "default struct values are provided" do
      config = Config.new()

      assert config.client_name
      assert config.pool_name
      assert config.pool_size
      assert config.queues
      assert config.reporter_name
      assert config.schedulers
    end

    test ":pool_size value is verified as an integer" do
      assert_raise ArgumentError, fn -> Config.new(pool_size: 0) end
      assert_raise ArgumentError, fn -> Config.new(pool_size: 1.1) end
    end

    test ":queues are validated as atom, integer pairs" do
      assert_raise ArgumentError, fn -> Config.new(queues: %{default: 25}) end
      assert_raise ArgumentError, fn -> Config.new(queues: [{"default", 25}]) end
      assert_raise ArgumentError, fn -> Config.new(queues: [default: 0]) end
      assert_raise ArgumentError, fn -> Config.new(queues: [default: 3.5]) end
    end

    test ":reporters are validated as modules" do
      defmodule BadModule do
      end

      assert_raise ArgumentError, fn -> Config.new(reporters: [nil]) end
      assert_raise ArgumentError, fn -> Config.new(reporters: ["FakeModule"]) end
      assert_raise ArgumentError, fn -> Config.new(reporters: [FakeModule]) end
      assert_raise ArgumentError, fn -> Config.new(reporters: [BadModule]) end
    end

    test ":schedulers are validated as a list of atoms or binaries" do
      assert_raise ArgumentError, fn -> Config.new(schedulers: %{retry: true}) end
      assert_raise ArgumentError, fn -> Config.new(schedulers: [retry: true]) end
      assert_raise ArgumentError, fn -> Config.new(schedulers: ["retry", 1]) end
    end

    test ":test_mode values are validated as a particular atom" do
      assert_raise ArgumentError, fn -> Config.new(test_mode: false) end
      assert_raise ArgumentError, fn -> Config.new(test_mode: :special) end
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
