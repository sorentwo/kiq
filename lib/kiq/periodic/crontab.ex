defmodule Kiq.Periodic.Crontab do
  @moduledoc """
  Generate and evaluate the structs used to evaluate periodic jobs.

  The `Crontab` module provides parsing and evaluation for standard cron
  expressions. Expressions are composed of rules specifying the minutes, hours,
  days, months and weekdays. Rules for each field are comprised of literal
  values, wildcards, step values or ranges:

    * `*` - Wildcard, matches any value (0, 1, 2, ...)
    * `0` — Literal, matches only itself (only 0)
    * `*/15` — Step, matches any value that is a multiple (0, 15, 30, 45)
    * `0-5` — Range, matches any value within the range (0, 1, 2, 3, 4, 5)

  Each part may have multiple rules, where rules are separated by a comma. The
  allowed values for each field are as follows:

    * `minute` - 0-59
    * `hour` - 0-23
    * `days` - 1-31
    * `month` - 1-12 (or aliases, `JAN`, `FEB`, `MAR`, etc.)
    * `weekdays` - 0-6 (or aliases, `SUN`, `MON`, `TUE`, etc.)

  For more in depth information see the man documentation for `cron` and
  `crontab` in your system. Alternatively you can experiment with various
  expressions online at [Crontab Guru](http://crontab.guru/).

  ## Examples

      # The first minute of every hour
      Crontab.parse!("0 * * * *")

      # Every fifteen minutes during standard business hours
      Crontab.parse!("*/15 9-17 * * *")

      # Once a day at midnight during december
      Crontab.parse!("0 0 * DEC *")

      # Once an hour during both rush hours on Friday the 13th
      Crontab.parse!("0 7-9,4-6 13 * FRI")
  """

  alias Kiq.Periodic.Parser

  @type expression :: [:*] | list(non_neg_integer())

  @type t :: %__MODULE__{
          minutes: expression(),
          hours: expression(),
          days: expression(),
          months: expression(),
          weekdays: expression()
        }

  defstruct minutes: [:*], hours: [:*], days: [:*], months: [:*], weekdays: [:*]

  # Evaluation

  @doc """
  Evaluate whether a crontab matches a datetime. The current datetime in UTC is
  used as the default.

  ## Examples

      iex> Kiq.Periodic.Crontab.now?(%Crontab{})
      true

      iex> crontab = Crontab.parse!("* * * * *")
      ...> Kiq.Periodic.Crontab.now?(crontab)
      true

      iex> crontab = Crontab.parse!("59 23 1 1 6")
      ...> Kiq.Periodic.Crontab.now?(crontab)
      false
  """
  @spec now?(crontab :: t(), datetime :: DateTime.t()) :: boolean()
  def now?(%__MODULE__{} = crontab, datetime \\ DateTime.utc_now()) do
    crontab
    |> Map.from_struct()
    |> Enum.all?(fn {part, values} ->
      Enum.any?(values, &matches_rule?(part, &1, datetime))
    end)
  end

  defp matches_rule?(_part, :*, _date_time), do: true
  defp matches_rule?(:minutes, minute, datetime), do: minute == datetime.minute
  defp matches_rule?(:hours, hour, datetime), do: hour == datetime.hour
  defp matches_rule?(:days, day, datetime), do: day == datetime.day
  defp matches_rule?(:months, month, datetime), do: month == datetime.month
  defp matches_rule?(:weekdays, weekday, datetime), do: weekday == Date.day_of_week(datetime)

  # Parsing

  @part_ranges %{
    minutes: {0, 59},
    hours: {0, 23},
    days: {1, 31},
    months: {1, 12},
    weekdays: {0, 6}
  }

  @doc """
  Parse a crontab expression string into a Crontab struct.

  ## Examples

      iex> Kiq.Periodic.Crontab.parse!("0 6,12,18 * * *")
      %Crontab{minutes: [0], hours: [6, 12, 18]}

      iex> Kiq.Periodic.Crontab.parse!("0-2,4-6 */12 * * *")
      %Crontab{minutes: [0, 1, 2, 4, 5, 6], hours: [0, 12]}

      iex> Kiq.Periodic.Crontab.parse!("* * 20,21 SEP,NOV *")
      %Crontab{days: [20, 21], months: [9, 11]}

      iex> Kiq.Periodic.Crontab.parse!("0 12 * * SUN")
      %Crontab{minutes: [0], hours: [12], weekdays: [0]}
  """
  @spec parse!(input :: binary()) :: t()
  def parse!(input) when is_binary(input) do
    case Parser.crontab(input) do
      {:ok, parsed, _, _, _, _} ->
        struct!(__MODULE__, expand(parsed))

      {:error, message, _, _, _, _} ->
        raise ArgumentError, message
    end
  end

  defp expand(parsed) when is_list(parsed), do: Enum.map(parsed, &expand/1)

  defp expand({part, expressions}) do
    {min, max} = Map.get(@part_ranges, part)

    expanded =
      expressions
      |> Enum.flat_map(&expand(&1, min, max))
      |> :lists.usort()

    {part, expanded}
  end

  defp expand({:wild, _value}, _min, _max), do: [:*]

  defp expand({:literal, value}, min, max) when value in min..max, do: [value]

  defp expand({:step, value}, min, max) when value in (min + 1)..max do
    for step <- min..max, rem(step, value) == 0, do: step
  end

  defp expand({:range, [first, last]}, min, max) when first >= min and last <= max do
    for step <- first..last, do: step
  end

  defp expand({_type, value}, min, max) do
    raise ArgumentError, "Unexpected value #{inspect(value)} outside of range #{min}..#{max}"
  end
end
