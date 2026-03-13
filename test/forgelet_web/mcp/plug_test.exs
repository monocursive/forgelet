defmodule ForgeletWeb.MCP.PlugTest do
  use ForgeletWeb.ConnCase, async: false

  alias Forgelet.Agent.SessionRegistry

  test "lists tools for the authenticated session", %{conn: conn} do
    agent_id = :crypto.strong_rand_bytes(32)
    {:ok, token} = SessionRegistry.create(agent_id, :coder, "/tmp/forgelet-test")

    conn =
      post(conn, ~p"/mcp/#{token}", %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => 1
      })

    assert %{"result" => %{"tools" => tools}} = json_response(conn, 200)
    assert Enum.any?(tools, &(&1["name"] == "forgelet_claim_intent"))
    refute Enum.any?(tools, &(&1["name"] == "forgelet_cast_vote"))
  end

  test "returns 404 for unknown sessions", %{conn: conn} do
    conn =
      post(conn, "/mcp/missing-token", %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => 1
      })

    assert %{"error" => %{"message" => "unknown session"}} = json_response(conn, 404)
  end
end
