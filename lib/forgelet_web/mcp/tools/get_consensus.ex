defmodule ForgeletWeb.MCP.Tools.GetConsensus do
  @behaviour ForgeletWeb.MCP.Tool

  alias Forgelet.Consensus.Engine
  alias ForgeletWeb.MCP.Tools.Helpers

  @impl true
  def definition do
    %{
      "name" => "forgelet_get_consensus",
      "description" => "Returns consensus status and votes for a proposal.",
      "inputSchema" => %{
        "type" => "object",
        "required" => ["proposal_ref"],
        "properties" => %{"proposal_ref" => %{"type" => "string"}}
      }
    }
  end

  @impl true
  def call(%{"proposal_ref" => proposal_ref}, _context) do
    {:ok, outcome} = Engine.evaluate(proposal_ref)

    votes =
      Helpers.proposal_votes(proposal_ref)
      |> Enum.map(fn event ->
        %{
          author: Forgelet.Identity.fingerprint(event.author),
          verdict: event.payload["verdict"],
          confidence: event.payload["confidence"]
        }
      end)

    {:ok,
     %{
       status: to_string(outcome),
       votes: votes,
       policy: Application.get_env(:forgelet, :default_consensus_policy)
     }}
  end

  def call(_params, _context), do: {:error, :invalid_params}
end
