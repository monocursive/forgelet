defmodule ForgeletWeb.MCP.Tool do
  @moduledoc """
  Behaviour for Forgelet MCP tool handlers.
  """

  @callback definition() :: map()
  @callback call(map(), map()) :: {:ok, term()} | {:error, term()}
end
