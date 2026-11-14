defmodule SturdyWeb.LocalDateTimeInputTest do
  # The configured timezone is America/New_York (UTC-5 in November).
  use ExUnit.Case, async: true

  alias SturdyWeb.LocalDateTimeInput, as: Input

  test "to_input/1 shows UTC timestamps in local time, to the minute" do
    assert Input.to_input(~U[2026-11-14 05:30:59Z]) == "2026-11-14T00:30"
    assert Input.to_input("2026-11-14T00:30") == "2026-11-14T00:30"
    assert Input.to_input(nil) == ""
  end

  test "to_utc/1 parses minute and second precision as local time" do
    assert Input.to_utc("2026-11-14T00:30") == {:ok, ~U[2026-11-14 05:30:00Z]}
    assert Input.to_utc("2026-11-14T00:30:15") == {:ok, ~U[2026-11-14 05:30:15Z]}
    assert Input.to_utc("yesterday") == :error
  end

  test "put_utc/2 converts the key when parseable and leaves other params alone" do
    assert Input.put_utc(%{"at" => "2026-11-14T00:30", "x" => 1}, "at") ==
             %{"at" => ~U[2026-11-14 05:30:00Z], "x" => 1}

    assert Input.put_utc(%{"at" => "nope"}, "at") == %{"at" => "nope"}
    assert Input.put_utc(%{}, "at") == %{}
  end
end
