defmodule SturdyWeb.PageController do
  use SturdyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
