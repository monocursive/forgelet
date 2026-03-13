defmodule ForgeletWeb.DashboardLiveTest do
  use ForgeletWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders dashboard with stats", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Mission Control"
    assert html =~ "Events"
    assert html =~ "Agents"
    assert html =~ "Repos"
  end
end
