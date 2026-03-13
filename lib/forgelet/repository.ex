defmodule Forgelet.Repository do
  @moduledoc """
  GenServer representing a code repository in the Forgelet network.

  Each repository is a Horde-distributed process registered via
  `Forgelet.Registry` and supervised by `Forgelet.RepoSupervisor`.
  It tracks intents, proposals, and participating agents, reacting to
  events broadcast over PubSub.
  """

  use GenServer

  require Logger

  alias Forgelet.{Event, EventStore}

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new repository, starts it under `Forgelet.RepoSupervisor`, and
  returns `{:ok, pid, repo_id}`.
  """
  def create(name, owner_keypair, opts \\ []) do
    repo_id = :crypto.hash(:sha256, name <> :crypto.strong_rand_bytes(16))

    child_spec =
      {__MODULE__, Keyword.merge(opts, name: name, owner: owner_keypair, repo_id: repo_id)}

    case Horde.DynamicSupervisor.start_child(Forgelet.RepoSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid, repo_id}
      {:error, _} = error -> error
    end
  end

  @doc false
  def start_link(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    GenServer.start_link(__MODULE__, opts, name: via(repo_id))
  end

  @doc """
  Returns the (sanitized) state of the repository identified by `repo_id`.
  """
  def get_state(repo_id) do
    GenServer.call(via(repo_id), :get_state)
  end

  @doc """
  Publishes an intent scoped to the given repository.
  """
  def publish_intent(repo_id, keypair, payload) do
    GenServer.call(via(repo_id), {:publish_intent, keypair, payload})
  end

  @doc """
  Lists all repositories currently registered in `Forgelet.Registry`.
  """
  def list_local do
    Horde.Registry.select(Forgelet.Registry, [
      {{{__MODULE__, :"$1"}, :"$2", :"$3"}, [], [%{repo_id: :"$1", pid: :"$2"}]}
    ])
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp via(repo_id) do
    {:via, Horde.Registry, {Forgelet.Registry, {__MODULE__, repo_id}}}
  end

  # ---------------------------------------------------------------------------
  # Server callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    owner = Keyword.fetch!(opts, :owner)
    repo_id = Keyword.fetch!(opts, :repo_id)

    repo_base_path = Application.get_env(:forgelet, :repo_base_path, "priv/repos")
    hex_id = Base.encode16(repo_id, case: :lower)
    path = Path.join(repo_base_path, hex_id)
    File.mkdir_p!(path)

    # Initialize bare git repo
    case System.cmd("git", ["init", "--bare"], cd: path, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> Logger.warning("Repository: git init --bare failed: #{output}")
    end

    scope = {:repo, repo_id}

    Phoenix.PubSub.subscribe(Forgelet.PubSub, "events:scope:repo:#{hex_id}")
    Phoenix.PubSub.subscribe(Forgelet.PubSub, "events:kind:consensus_reached")

    # Publish the :repo_created event asynchronously so the GenServer finishes init first.
    Process.send_after(self(), :publish_created, 0)

    policy = Application.get_env(:forgelet, :default_consensus_policy, {:threshold, 2, 0.7})

    {:ok,
     %{
       id: repo_id,
       name: name,
       path: path,
       owner: owner,
       policy: policy,
       active_intents: %{},
       active_proposals: %{},
       agents: MapSet.new(),
       scope: scope,
       created_at: System.os_time(:millisecond)
     }}
  end

  @impl true
  def handle_info(:publish_created, state) do
    case Event.new(:repo_created, state.owner, %{"name" => state.name}, scope: state.scope) do
      {:ok, event} ->
        case EventStore.append(event) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning("Repository: failed to append repo_created: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("Repository: failed to create repo_created event: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info({:event, %{kind: :intent_claimed} = event}, state) do
    agent_key = event.author
    {:noreply, %{state | agents: MapSet.put(state.agents, agent_key)}}
  end

  def handle_info({:event, %{kind: :proposal_submitted} = event}, state) do
    # Store proposals by hex-encoded ref for consistent matching
    proposal_ref = Event.ref(event)
    {:noreply, %{state | active_proposals: Map.put(state.active_proposals, proposal_ref, event)}}
  end

  def handle_info({:event, %{kind: :consensus_reached} = event}, state) do
    proposal_ref = event.payload["proposal_ref"]
    outcome = event.payload["outcome"]

    if Map.has_key?(state.active_proposals, proposal_ref) do
      result_kind =
        if outcome in [:accepted, "accepted"], do: :merge_executed, else: :merge_rejected

      case Event.new(result_kind, state.owner, %{"proposal_ref" => proposal_ref},
             scope: state.scope
           ) do
        {:ok, result_event} ->
          case EventStore.append(result_event) do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.warning("Repository: failed to append #{result_kind}: #{inspect(reason)}")
          end

        {:error, reason} ->
          Logger.warning("Repository: failed to create #{result_kind} event: #{inspect(reason)}")
      end

      {:noreply, %{state | active_proposals: Map.delete(state.active_proposals, proposal_ref)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:event, _}, state), do: {:noreply, state}

  @impl true
  def handle_call(:get_state, _from, state) do
    sanitized = %{state | owner: %{public: state.owner.public}}
    {:reply, sanitized, state}
  end

  def handle_call({:publish_intent, keypair, payload}, _from, state) do
    case Event.new(:intent_published, keypair, payload, scope: state.scope) do
      {:ok, event} ->
        case EventStore.append(event) do
          {:ok, _} ->
            updated_intents = Map.put(state.active_intents, event.id, event)
            {:reply, {:ok, event}, %{state | active_intents: updated_intents}}

          {:error, _} = error ->
            {:reply, error, state}
        end

      {:error, _} = error ->
        {:reply, error, state}
    end
  end
end
