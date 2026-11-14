defmodule SturdyWeb.Router do
  use SturdyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SturdyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :basic_auth
  end

  scope "/", SturdyWeb do
    pipe_through :browser

    live_session :default do
      live "/", DayLive, :today
      live "/days/:date", DayLive, :show
      live "/days/:date/plan", PlannedSetLive.New, :new
      live "/days/:date/log", CompletedSetLive.Form, :new
      live "/planned/:id/edit", PlannedSetLive.Edit, :edit
      live "/completed/:id/edit", CompletedSetLive.Form, :edit

      live "/movements", MovementLive.Index, :index
      live "/movements/new", MovementLive.Form, :new
      live "/movements/:id", MovementLive.Show, :show
      live "/movements/:id/edit", MovementLive.Form, :edit

      live "/tags", TagLive.Index, :index
      live "/bodyweight", BodyweightLive.Index, :index
    end
  end

  # Sturdy is single-user with no accounts. When deployed, set credentials in
  # config :sturdy, :basic_auth (see config/runtime.exs) to guard every page.
  defp basic_auth(conn, _opts) do
    case Application.get_env(:sturdy, :basic_auth) do
      nil -> conn
      credentials -> Plug.BasicAuth.basic_auth(conn, credentials)
    end
  end
end
