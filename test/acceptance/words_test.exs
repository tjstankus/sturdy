defmodule Sturdy.Acceptance.WordsTest do
  use ExUnit.Case, async: true

  alias Sturdy.Acceptance.Words

  @today ~D[2026-11-10]

  test "date words resolve against today" do
    assert Words.date("today", @today) == ~D[2026-11-10]
    assert Words.date("tomorrow", @today) == ~D[2026-11-11]
    assert Words.date("yesterday", @today) == ~D[2026-11-09]
    assert Words.date("in 3 days", @today) == ~D[2026-11-13]
    assert Words.date("in 1 day", @today) == ~D[2026-11-11]
    assert Words.date("2 days ago", @today) == ~D[2026-11-08]
    assert Words.date("2026-12-25", @today) == ~D[2026-12-25]
  end

  test "local date-times pair a date word with a time" do
    assert Words.local_datetime("tomorrow 00:30", @today) == ~N[2026-11-11 00:30:00]
    assert Words.local_datetime("in 2 days 7:05", @today) == ~N[2026-11-12 07:05:00]
    assert Words.local_datetime("2026-11-10 08:00", @today) == ~N[2026-11-10 08:00:00]
  end

  test "times may drop the leading zero" do
    assert Words.time("8:00") == ~T[08:00:00]
    assert Words.time("14:35") == ~T[14:35:00]
  end

  test "summaries compare ignoring separators and spacing" do
    assert Words.summary("30s · L") == Words.summary("30s L")
    assert Words.summary(" 8 reps ·  20 lb ") == "8 reps 20 lb"
    assert Words.summary(nil) == nil
  end
end
