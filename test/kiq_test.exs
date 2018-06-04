defmodule KiqTest do
  use ExUnit.Case
  doctest Kiq

  test "greets the world" do
    assert Kiq.hello() == :world
  end
end
