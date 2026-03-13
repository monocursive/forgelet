defmodule ForgeletWeb.MCP.Tools.ListAgents do
  @behaviour ForgeletWeb.MCP.Tool

  alias Forgelet.{Agent, Identity}

  @impl true
  def definition do
    %{
      "name" => "forgelet_list_agents",
      "description" => "Lists local Forgelet agents and their current state.",
      "inputSchema" => %{"type" => "object", "properties" => %{}}
    }
  end

  @impl true
  def call(_params, _context) do
    agents =
      Agent.list_local()
      |> Enum.map(fn {agent_id, _pid} ->
        state = Agent.inspect_state(agent_id)

        %{
          fingerprint: Identity.fingerprint(agent_id),
          kind: state.kind,
          status: state.status,
          reputation: state.reputation,
          current_task: state.current_task
        }
      end)

    {:ok, agents}
  end
end
