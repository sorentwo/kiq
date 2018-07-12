defmodule Kiq.ConfigTest do
  use Kiq.Case, async: true

  alias Kiq.Config

  describe "new/1" do
    test "default struct values are preserved" do
      config = Config.new()

      assert config.client
      assert config.client_name
      assert config.reporter_name
      assert config.schedulers
      assert config.queues
    end

    test "provided values are not overwritten" do
      config = Config.new(client: My.Special.Client, client_opts: [special: true])

      assert config.client == My.Special.Client
      assert config.client_opts == [special: true]
    end
  end
end
