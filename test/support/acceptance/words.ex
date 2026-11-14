defmodule Sturdy.Acceptance.Words do
  @moduledoc """
  How specs write dates, times, and set summaries, turned into values.

    * dates: `"today"`, `"tomorrow"`, `"yesterday"`, `"in 3 days"`, `"3 days ago"`,
      or ISO `"2026-11-10"`
    * local date-times: a date word and a time, `"tomorrow 00:30"`,
      `"2026-11-10 08:00"`
    * times: `"8:00"`, `"08:00"`, `"14:35"`
    * summaries: compared ignoring separators, so `"30s L"` matches the
      screen's `"30s · L"`
  """

  @spec date(String.t(), Date.t()) :: Date.t()
  def date("today", today), do: today
  def date("tomorrow", today), do: Date.add(today, 1)
  def date("yesterday", today), do: Date.add(today, -1)
  def date("in " <> days, today), do: Date.add(today, count_days(days))

  def date(words, today) when binary_part(words, byte_size(words), -4) == " ago",
    do: Date.add(today, -count_days(String.trim_trailing(words, " ago")))

  def date(iso, _today), do: Date.from_iso8601!(iso)

  @spec local_datetime(String.t(), Date.t()) :: NaiveDateTime.t()
  def local_datetime(words, today) do
    {day, [time]} = words |> String.split(" ") |> Enum.split(-1)
    NaiveDateTime.new!(date(Enum.join(day, " "), today), time(time))
  end

  @spec time(String.t()) :: Time.t()
  def time(hours_minutes),
    do: Time.from_iso8601!(String.pad_leading(hours_minutes, 5, "0") <> ":00")

  @spec summary(String.t() | nil) :: String.t() | nil
  def summary(nil), do: nil
  def summary(text), do: text |> String.replace("·", " ") |> String.split() |> Enum.join(" ")

  # "3 days" or "1 day"
  defp count_days(words) do
    {count, " day" <> _plural} = Integer.parse(words)
    count
  end
end
