defmodule Kiq.ConfigTest do
  use Kiq.Case, async: true

  alias Kiq.Config

  describe "new/1" do
    test "default struct values are provided" do
      config = Config.new()

      assert config.client
      assert config.client_name
      assert config.queues
      assert config.reporter_name
      assert config.schedulers
    end

    test "an identity value is automatically included" do
      config = Config.new()

      assert config.identity
      assert is_binary(config.identity)
    end

    test "provided values are not overwritten" do
      config =
        Config.new(
          client: My.Special.Client,
          client_opts: [special: true],
          identity: "my.custom.ident"
        )

      assert config.client == My.Special.Client
      assert config.client_opts == [special: true]
      assert config.identity == "my.custom.ident"
    end
  end
end
