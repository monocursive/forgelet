defmodule ForgeletWeb.MCP.ToolRegistry do
  @moduledoc """
  Maps MCP tool names to handler modules and authorized agent kinds.
  """

  alias ForgeletWeb.MCP.Tools

  @tools %{
    "forgelet_get_state" => {Tools.GetAgentState, [:coder, :reviewer, :orchestrator]},
    "forgelet_query_events" => {Tools.QueryEvents, [:coder, :reviewer, :orchestrator]},
    "forgelet_get_repo_state" => {Tools.GetRepoState, [:coder, :reviewer, :orchestrator]},
    "forgelet_list_intents" => {Tools.ListIntents, [:coder, :orchestrator]},
    "forgelet_claim_intent" => {Tools.ClaimIntent, [:coder]},
    "forgelet_prepare_workspace" => {Tools.PrepareWorkspace, [:coder]},
    "forgelet_publish_artifact" => {Tools.PublishArtifact, [:coder]},
    "forgelet_submit_proposal" => {Tools.SubmitProposal, [:coder]},
    "forgelet_run_tests" => {Tools.RunTests, [:coder]},
    "forgelet_list_proposals" => {Tools.ListProposals, [:reviewer, :orchestrator]},
    "forgelet_get_diff" => {Tools.GetDiff, [:reviewer]},
    "forgelet_cast_vote" => {Tools.CastVote, [:reviewer]},
    "forgelet_publish_comment" => {Tools.PublishComment, [:reviewer]},
    "forgelet_publish_intent" => {Tools.PublishIntent, [:orchestrator]},
    "forgelet_list_agents" => {Tools.ListAgents, [:orchestrator]},
    "forgelet_get_consensus" => {Tools.GetConsensus, [:orchestrator]}
  }

  def list_for_kind(kind) do
    @tools
    |> Enum.filter(fn {_name, {_module, allowed_kinds}} -> kind in allowed_kinds end)
    |> Enum.map(fn {_name, {module, _allowed_kinds}} -> module.definition() end)
  end

  def dispatch(name, arguments, %{kind: kind} = context) do
    case Map.get(@tools, name) do
      {module, allowed_kinds} ->
        if kind in allowed_kinds,
          do: module.call(arguments, context),
          else: {:error, :unauthorized}

      nil ->
        {:error, :tool_not_found}
    end
  end
end
