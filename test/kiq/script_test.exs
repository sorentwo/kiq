defmodule Kiq.ScriptTest do
  use Kiq.Case, async: true

  alias Kiq.Script

  describe "path/1" do
    test "converting a name into fully qualified script path" do
      assert Script.path("dequeue") =~ "priv/scripts/dequeue.lua"
      assert Script.path("deschedule") =~ "priv/scripts/deschedule.lua"
    end
  end

  describe "hash/1" do
    test "a lower case sha1 hash is built for the script" do
      known_script = "dequeue"

      assert Script.hash(known_script) =~ ~r/^[a-z0-9]{40}$/
    end
  end
end
