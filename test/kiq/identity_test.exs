defmodule Kiq.IdentityTest do
  use ExUnit.Case, async: true

  alias Kiq.Identity

  describe "hostname/1" do
    test "the system's DYNO value is favored when available" do
      assert Identity.hostname(%{"DYNO" => "worker.1"}) == "worker.1"
    end

    test "the local hostname is used without a DYNO variable" do
      hostname = Identity.hostname()

      assert is_binary(hostname)
      assert String.length(hostname) > 1
    end
  end

  describe "nonce/1" do
    test "a fixed length random string of ascii characters is returned" do
      assert Identity.nonce(8) =~ ~r/^[a-z0-9]{8}$/
    end
  end

  describe "identity/1" do
    test "it composes the hostname, pid and nonce together" do
      hostname = "worker.1"
      identity = Identity.identity(%{"DYNO" => hostname})

      assert identity =~ ~r/^#{hostname}:<0\.\d+\.0>:[a-z0-9]+$/
    end
  end
end
