defmodule Forgelet.Schema.ProposalTest do
  use ExUnit.Case, async: true

  alias Forgelet.Schema

  describe "proposal_submitted" do
    test "valid event passes" do
      event = %{
        kind: :proposal_submitted,
        payload: %{
          "intent_ref" => "intent_abc",
          "commit_range" => %{"from" => "aaa111", "to" => "bbb222"}
        }
      }

      assert :ok = Schema.validate(event)
    end

    test "missing intent_ref fails" do
      event = %{
        kind: :proposal_submitted,
        payload: %{
          "commit_range" => %{"from" => "aaa111", "to" => "bbb222"}
        }
      }

      assert {:error, "missing required field: intent_ref"} = Schema.validate(event)
    end

    test "missing commit_range fails" do
      event = %{
        kind: :proposal_submitted,
        payload: %{"intent_ref" => "intent_abc"}
      }

      assert {:error, "missing required field: commit_range"} = Schema.validate(event)
    end

    test "malformed commit_range fails" do
      event = %{
        kind: :proposal_submitted,
        payload: %{
          "intent_ref" => "intent_abc",
          "commit_range" => %{"from" => "aaa111"}
        }
      }

      assert {:error, _reason} = Schema.validate(event)
    end
  end

  describe "proposal_updated" do
    test "valid event passes" do
      event = %{
        kind: :proposal_updated,
        payload: %{"intent_ref" => "intent_abc", "proposal_ref" => "prop_123"}
      }

      assert :ok = Schema.validate(event)
    end

    test "missing intent_ref fails" do
      event = %{
        kind: :proposal_updated,
        payload: %{"proposal_ref" => "prop_123"}
      }

      assert {:error, "missing required field: intent_ref"} = Schema.validate(event)
    end

    test "missing proposal_ref fails" do
      event = %{
        kind: :proposal_updated,
        payload: %{"intent_ref" => "intent_abc"}
      }

      assert {:error, "missing required field: proposal_ref"} = Schema.validate(event)
    end
  end

  describe "proposal_withdrawn" do
    test "valid event passes" do
      event = %{
        kind: :proposal_withdrawn,
        payload: %{"intent_ref" => "intent_abc", "proposal_ref" => "prop_123"}
      }

      assert :ok = Schema.validate(event)
    end

    test "missing proposal_ref fails" do
      event = %{
        kind: :proposal_withdrawn,
        payload: %{"intent_ref" => "intent_abc"}
      }

      assert {:error, "missing required field: proposal_ref"} = Schema.validate(event)
    end
  end
end
