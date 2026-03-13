defmodule Forgelet.Agent.SessionRegistryTest do
  use ExUnit.Case, async: false

  alias Forgelet.Agent.SessionRegistry

  test "creates, looks up, and invalidates a token" do
    agent_id = :crypto.strong_rand_bytes(32)
    {:ok, token} = SessionRegistry.create(agent_id, :coder, "/tmp/workspace")

    assert {:ok, session} = SessionRegistry.lookup(token)
    assert session.agent_id == agent_id
    assert session.kind == :coder
    assert session.working_dir == "/tmp/workspace"

    assert :ok = SessionRegistry.invalidate(token)
    assert :error = SessionRegistry.lookup(token)
  end
end
