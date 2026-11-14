defmodule SturdyWeb.RouterTest do
  # Changes application env, so not async.
  use SturdyWeb.ConnCase, async: false

  setup do
    on_exit(fn -> Application.delete_env(:sturdy, :basic_auth) end)
  end

  test "pages are open when no credentials are configured", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200)
  end

  test "pages require basic auth when credentials are configured", %{conn: conn} do
    Application.put_env(:sturdy, :basic_auth, username: "me", password: "secret")

    assert conn |> get(~p"/") |> response(401)

    authorized =
      put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("me", "secret"))

    assert authorized |> get(~p"/") |> html_response(200)
  end
end
