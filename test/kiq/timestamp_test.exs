defmodule Kiq.TimestampTest do
  use ExUnit.Case, async: true

  alias Kiq.Timestamp

  describe "date_now/0" do
    test "the current date is returned" do
      assert Timestamp.date_now() =~ ~r|\d{4}-\d{2}-\d{2}|
    end
  end

  describe "unix_now/0" do
    test "the current time is returned as a float" do
      assert to_string(Timestamp.unix_now()) =~ ~r|\d{9}\.\d+|
    end
  end

  describe "unix_in/2" do
    test "a time in the future is returned as a float" do
      now = Timestamp.unix_now()
      offset = Timestamp.unix_in(1, :seconds)

      assert offset > now
      assert_in_delta offset, now, 1.5
    end
  end

  describe "to_score/1" do
    test "timestamps are converted to a ranking score" do
      assert Timestamp.to_score(1_527_003_414_093_447) == "1527003414.093447"
    end
  end
end
