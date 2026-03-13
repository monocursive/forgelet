defmodule ForgeletWeb.PageController do
  use ForgeletWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
