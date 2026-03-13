defmodule ForgeletWeb.RepoListLiveTest do
  use ForgeletWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders repo list", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/repos")

    assert html =~ "Repositories"
  end
end
