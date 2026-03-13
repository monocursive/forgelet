defmodule ForgeletWeb.EventFeedLiveTest do
  use ForgeletWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders event feed", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/events")

    assert html =~ "Event Feed"
    assert html =~ "All"
  end
end
