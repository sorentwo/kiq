defmodule Kiq.Periodic.CrontabTest do
  use Kiq.Case, async: true
  use ExUnitProperties

  alias Kiq.Periodic.Crontab

  doctest Crontab

  describe "parse!/1" do
    property "literal values and aliases are parsed" do
      check all minutes <- integer(0..59),
                hours <- integer(0..23),
                days <- integer(1..31),
                months <- one_of([integer(1..12), constant("JAN")]),
                weekdays <- one_of([integer(0..6), constant("MON")]) do
        Crontab.parse!(Enum.join([minutes, hours, days, months, weekdays], " "))
      end
    end

    property "expressions with wildcards, ranges, steps and lists are parsed" do
      expression =
        one_of([
          constant("*"),
          map(integer(1..59), &"*/#{&1}"),
          map(integer(1..58), &"#{&1}-#{&1 + 1}"),
          list_of(integer(0..59), length: 1..10)
        ])

      check all minutes <- expression do
        combined = minutes |> List.wrap() |> Enum.join(",")

        Crontab.parse!(combined <> " * * * *")
      end
    end

    test "any expression out of bounds fails parsing" do
      assert_raise ArgumentError, fn -> Crontab.parse!("60 * * * *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* 24 * * *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* * 32 * *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* * * 13 *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* * * * 7") end
      assert_raise ArgumentError, fn -> Crontab.parse!("*/0 * * * *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("ONE * * * *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* * * jan *") end
      assert_raise ArgumentError, fn -> Crontab.parse!("* * * * sun") end
    end
  end

  describe "now?/2" do
    property "literal values always match the current datetime" do
      check all minute <- integer(1..59),
                hour <- integer(1..23),
                day <- integer(2..28),
                month <- integer(2..12) do
        crontab = %Crontab{minutes: [minute], hours: [hour], days: [day], months: [month]}
        datetime = %{DateTime.utc_now() | minute: minute, hour: hour, day: day, month: month}

        assert Crontab.now?(crontab, datetime)
        refute Crontab.now?(crontab, %{datetime | minute: minute - 1})
        refute Crontab.now?(crontab, %{datetime | hour: hour - 1})
        refute Crontab.now?(crontab, %{datetime | day: day - 1})
        refute Crontab.now?(crontab, %{datetime | month: month - 1})
      end
    end
  end
end
