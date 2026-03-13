defmodule ForgeletWeb.PageControllerTest do
  use ForgeletWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / redirects to dashboard live view", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Mission Control"
  end
end
