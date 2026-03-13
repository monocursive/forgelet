defmodule ForgeletWeb.MCP.Tools.ListIntents do
  @behaviour ForgeletWeb.MCP.Tool

  alias Forgelet.Repository
  alias ForgeletWeb.MCP.Tools.Helpers

  @impl true
  def definition do
    %{
      "name" => "forgelet_list_intents",
      "description" => "Lists open, unclaimed intents for a repository.",
      "inputSchema" => %{
        "type" => "object",
        "required" => ["repo_id"],
        "properties" => %{"repo_id" => %{"type" => "string"}}
      }
    }
  end

  @impl true
  def call(%{"repo_id" => repo_id}, _context) do
    repo_id_binary = Helpers.decode_repo_id(repo_id)

    intents =
      Repository.list_open_intents(repo_id_binary)
      |> Enum.map(fn event ->
        %{
          ref: Forgelet.Event.ref(event),
          title: event.payload["title"],
          description: event.payload["description"],
          priority: event.payload["priority"],
          tags: event.payload["tags"] || []
        }
      end)

    {:ok, intents}
  catch
    :exit, _reason -> {:error, :repo_not_found}
  end

  def call(_params, _context), do: {:error, :invalid_params}
end
