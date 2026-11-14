defmodule Sturdy.ClockTest do
  # Sets the VM-wide test clock, so not async.
  use ExUnit.Case, async: false

  alias Sturdy.Clock
  alias Sturdy.LocalTime
  alias Sturdy.SettableClock

  setup do
    on_exit(&SettableClock.reset/0)
  end

  test "utc_now/0 comes from the configured clock, to the second" do
    SettableClock.set(~U[2026-11-11 05:30:00.123456Z])
    assert Clock.utc_now() == ~U[2026-11-11 05:30:00Z]
  end

  test "today is the local date of the clock's now" do
    # 00:30 in New York on Nov 11.
    SettableClock.set(~U[2026-11-11 05:30:00Z])
    assert LocalTime.today() == ~D[2026-11-11]

    # 23:30 in New York on Nov 10.
    SettableClock.set(~U[2026-11-11 04:30:00Z])
    assert LocalTime.today() == ~D[2026-11-10]
  end

  test "an unset test clock and the system clock tell the real time" do
    assert abs(DateTime.diff(DateTime.utc_now(), Clock.utc_now())) <= 1
    assert abs(DateTime.diff(DateTime.utc_now(), Clock.System.utc_now())) <= 1
  end
end
