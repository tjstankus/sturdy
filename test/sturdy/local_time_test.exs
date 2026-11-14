defmodule Sturdy.LocalTimeTest do
  # The configured timezone is America/New_York.
  use ExUnit.Case, async: true

  alias Sturdy.LocalTime

  test "a 12:30am local set belongs to the new local day" do
    # 00:30 EST on Nov 15 is 05:30 UTC.
    assert LocalTime.date_of(~U[2026-11-15 05:30:00Z]) == ~D[2026-11-15]
    # 23:30 EST on Nov 14 is 04:30 UTC the next day.
    assert LocalTime.date_of(~U[2026-11-15 04:30:00Z]) == ~D[2026-11-14]
  end

  test "day_bounds/1 is local midnight to midnight, in UTC" do
    assert LocalTime.day_bounds(~D[2026-11-14]) ==
             {~U[2026-11-14 05:00:00Z], ~U[2026-11-15 05:00:00Z]}
  end

  test "day_bounds/1 spans 23 hours on spring-forward day" do
    {day_start, next_start} = LocalTime.day_bounds(~D[2026-03-08])
    assert DateTime.diff(next_start, day_start, :hour) == 23
  end

  test "from_local/1 resolves ambiguous times to the earlier instant" do
    # 01:30 happens twice on 2026-11-01; the first is EDT (UTC-4).
    assert LocalTime.from_local(~N[2026-11-01 01:30:00]) == ~U[2026-11-01 05:30:00Z]
  end

  test "from_local/1 resolves times in a DST gap to just after it" do
    # 02:30 does not exist on 2026-03-08; the clock jumps to 03:00 EDT.
    assert LocalTime.from_local(~N[2026-03-08 02:30:00]) == ~U[2026-03-08 07:00:00Z]
  end

  test "to_local/1 and today/0" do
    assert %DateTime{time_zone: "America/New_York"} = LocalTime.to_local(~U[2026-11-14 12:00:00Z])
    assert %Date{} = LocalTime.today()
  end
end
