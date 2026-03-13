defmodule Forgelet.Schema.CapabilityTest do
  use ExUnit.Case, async: true

  alias Forgelet.Schema

  describe "capability_granted" do
    test "valid event passes" do
      event = %{
        kind: :capability_granted,
        payload: %{
          "grantee" => "agent_abc",
          "scope" => "repo:forgelet",
          "permissions" => ["read", "write"]
        }
      }

      assert :ok = Schema.validate(event)
    end

    test "missing grantee fails" do
      event = %{
        kind: :capability_granted,
        payload: %{
          "scope" => "repo:forgelet",
          "permissions" => ["read"]
        }
      }

      assert {:error, "missing required field: grantee"} = Schema.validate(event)
    end

    test "missing scope fails" do
      event = %{
        kind: :capability_granted,
        payload: %{
          "grantee" => "agent_abc",
          "permissions" => ["read"]
        }
      }

      assert {:error, "missing required field: scope"} = Schema.validate(event)
    end

    test "missing permissions fails" do
      event = %{
        kind: :capability_granted,
        payload: %{
          "grantee" => "agent_abc",
          "scope" => "repo:forgelet"
        }
      }

      assert {:error, "missing required field: permissions"} = Schema.validate(event)
    end

    test "non-list permissions fails" do
      event = %{
        kind: :capability_granted,
        payload: %{
          "grantee" => "agent_abc",
          "scope" => "repo:forgelet",
          "permissions" => "read"
        }
      }

      assert {:error, "permissions must be a list"} = Schema.validate(event)
    end
  end

  describe "capability_revoked" do
    test "valid event passes" do
      event = %{
        kind: :capability_revoked,
        payload: %{"grantee" => "agent_abc"}
      }

      assert :ok = Schema.validate(event)
    end

    test "missing grantee fails" do
      event = %{
        kind: :capability_revoked,
        payload: %{}
      }

      assert {:error, "missing required field: grantee"} = Schema.validate(event)
    end
  end
end
