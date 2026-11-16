defmodule SturdyWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias SturdyWeb.Layouts

  defp flash_group(flash) do
    (&Layouts.flash_group/1)
    |> render_component(flash: flash)
    |> LazyHTML.from_fragment()
  end

  test "notices dismiss themselves after a short while" do
    notice = flash_group(%{"info" => "Movement saved."}) |> LazyHTML.query("#flash-info")

    assert LazyHTML.text(notice) =~ "Movement saved."
    assert [hook] = LazyHTML.attribute(notice, "phx-hook")
    assert hook =~ "AutoDismiss"
    assert LazyHTML.attribute(notice, "data-dismiss-after") == ["2500"]
  end

  test "errors stay until dismissed" do
    error = flash_group(%{"error" => "That isn't a date."}) |> LazyHTML.query("#flash-error")

    assert LazyHTML.text(error) =~ "That isn't a date."
    assert LazyHTML.attribute(error, "phx-hook") == []
  end
end
