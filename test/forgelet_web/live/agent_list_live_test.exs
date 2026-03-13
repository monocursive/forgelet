defmodule ForgeletWeb.AgentListLiveTest do
  use ForgeletWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders agent list", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/agents")

    assert html =~ "Agents"
  end
end
