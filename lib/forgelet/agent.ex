defmodule Forgelet.Agent do
  @moduledoc """
  GenServer representing an AI agent in the Forgelet network.

  Each agent has its own Ed25519 keypair, is registered in the Horde cluster
  registry, and communicates exclusively through signed events appended to the
  EventStore.
  """

  use GenServer

  require Logger

  alias Forgelet.{Event, EventStore, Identity}
  alias Forgelet.Identity.Provenance

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Spawns a new agent of the given `kind` via the Horde DynamicSupervisor.

  Returns `{:ok, pid, public_key}` on success.

  ## Options

    * `:keypair` — pre-generated keypair; one is created if omitted.
    * `:model` — model name string (e.g. "claude-sonnet-4")
    * `:model_version` — model version string
    * `:capabilities` — list of capability strings
    * `:spawner` — public key of the spawning agent/node
    * Any additional opts are forwarded to `start_link/1`.
  """
  def spawn(kind, opts \\ []) do
    keypair = Keyword.get(opts, :keypair, Identity.generate())
    child_spec = {__MODULE__, Keyword.merge(opts, keypair: keypair, kind: kind)}

    case Horde.DynamicSupervisor.start_child(Forgelet.AgentSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid, keypair.public}
      {:error, _} = error -> error
    end
  end

  @doc false
  def start_link(opts) do
    keypair = Keyword.fetch!(opts, :keypair)

    GenServer.start_link(__MODULE__, opts, name: via(keypair.public))
  end

  @doc """
  Returns the agent's state with the secret key redacted.
  """
  def inspect_state(agent_id) do
    GenServer.call(via(agent_id), :inspect_state)
  end

  @doc """
  Instructs the agent to claim an intent by reference.
  Returns `{:ok, event_ref}` on success.
  """
  def claim_intent(agent_id, intent_ref, scope \\ nil) do
    GenServer.call(via(agent_id), {:claim_intent, intent_ref, scope})
  end

  @doc """
  Instructs the agent to submit a proposal with the given payload.
  Returns `{:ok, event_ref}` on success.
  """
  def submit_proposal(agent_id, payload, scope \\ nil) do
    GenServer.call(via(agent_id), {:submit_proposal, payload, scope})
  end

  @doc """
  Instructs the agent to cast a vote on a proposal.
  Returns `{:ok, event_ref}` on success.
  """
  def vote(agent_id, proposal_ref, verdict, opts \\ []) do
    GenServer.call(via(agent_id), {:vote, proposal_ref, verdict, opts})
  end

  @doc """
  Returns a list of `{agent_id, pid}` tuples for all agents registered locally.
  """
  def list_local do
    Horde.Registry.select(Forgelet.Registry, [
      {{{__MODULE__, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}
    ])
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp via(agent_id) do
    {:via, Horde.Registry, {Forgelet.Registry, {__MODULE__, agent_id}}}
  end

  # ---------------------------------------------------------------------------
  # Server callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    keypair = Keyword.fetch!(opts, :keypair)
    kind = Keyword.fetch!(opts, :kind)

    Phoenix.PubSub.subscribe(Forgelet.PubSub, "events")

    # Publish the join event asynchronously so init doesn't block on EventStore.
    Process.send_after(self(), :publish_joined, 0)

    {:ok,
     %{
       keypair: keypair,
       kind: kind,
       provenance: nil,
       capabilities: [],
       current_task: nil,
       reputation: 0.5,
       status: :idle,
       model: Keyword.get(opts, :model),
       model_version: Keyword.get(opts, :model_version),
       spawner: Keyword.get(opts, :spawner)
     }}
  end

  @impl true
  def handle_info(:publish_joined, state) do
    case Event.new(:agent_joined, state.keypair, %{"kind" => to_string(state.kind)}) do
      {:ok, joined_event} ->
        case EventStore.append(joined_event) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning("Agent: failed to append agent_joined: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("Agent: failed to create agent_joined event: #{inspect(reason)}")
    end

    provenance_attrs = %{
      agent_id: state.keypair.public,
      kind: state.kind,
      created_at: System.os_time(:millisecond),
      model: state.model,
      model_version: state.model_version,
      spawner: state.spawner,
      capabilities: Keyword.get([], :capabilities, [])
    }

    case Provenance.new(provenance_attrs) do
      {:ok, provenance} ->
        # Encode binary fields to hex so the payload is JSON-safe for Postgres.
        prov_payload =
          provenance
          |> Map.from_struct()
          |> Map.new(fn
            {k, v} when is_binary(v) and byte_size(v) > 0 ->
              if String.printable?(v),
                do: {to_string(k), v},
                else: {to_string(k), Base.encode16(v, case: :lower)}

            {k, v} when is_atom(v) ->
              {to_string(k), to_string(v)}

            {k, v} when is_list(v) ->
              {to_string(k), Enum.map(v, &to_string/1)}

            {k, nil} ->
              {to_string(k), nil}

            {k, v} ->
              {to_string(k), v}
          end)

        case Event.new(:agent_provenance, state.keypair, prov_payload) do
          {:ok, prov_event} ->
            case EventStore.append(prov_event) do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                Logger.warning("Agent: failed to append provenance: #{inspect(reason)}")
            end

          {:error, reason} ->
            Logger.warning("Agent: failed to create provenance event: #{inspect(reason)}")
        end

        {:noreply, %{state | provenance: provenance}}

      {:error, reason} ->
        Logger.warning("Agent: failed to create provenance: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, %{kind: :consensus_reached} = event}, state) do
    # Only reset if this consensus is about our current task
    proposal_ref = event.payload["proposal_ref"]

    if state.current_task && state.current_task == proposal_ref do
      {:noreply, %{state | status: :idle, current_task: nil}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, %{kind: :capability_granted} = event}, state) do
    agent_id = event.payload["agent_id"]

    if agent_id == state.keypair.public do
      capability = event.payload["capability"]
      {:noreply, %{state | capabilities: [capability | state.capabilities]}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:claim_intent, intent_ref, scope}, _from, state) do
    opts =
      if scope,
        do: [scope: scope, references: [{:intent, intent_ref}]],
        else: [references: [{:intent, intent_ref}]]

    case Event.new(:intent_claimed, state.keypair, %{"intent_ref" => intent_ref}, opts) do
      {:ok, event} ->
        case EventStore.append(event) do
          {:ok, stored} ->
            {:reply, {:ok, Event.ref(stored)},
             %{state | status: :working, current_task: intent_ref}}

          {:error, _} = error ->
            {:reply, error, state}
        end

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:submit_proposal, payload, scope}, _from, state) do
    opts = if scope, do: [scope: scope], else: []

    # Add references if intent_ref is in the payload
    opts =
      case payload["intent_ref"] do
        nil -> opts
        ref -> Keyword.put(opts, :references, [{:intent, ref}])
      end

    case Event.new(:proposal_submitted, state.keypair, payload, opts) do
      {:ok, event} ->
        case EventStore.append(event) do
          {:ok, stored} ->
            {:reply, {:ok, Event.ref(stored)}, state}

          {:error, _} = error ->
            {:reply, error, state}
        end

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:vote, proposal_ref, verdict, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    confidence = Keyword.get(opts, :confidence, 1.0)

    vote_payload = %{
      "proposal_ref" => proposal_ref,
      "verdict" => to_string(verdict),
      "confidence" => confidence
    }

    event_opts =
      [references: [{:proposal, proposal_ref}]] ++
        if(scope, do: [scope: scope], else: [])

    case Event.new(:vote_cast, state.keypair, vote_payload, event_opts) do
      {:ok, event} ->
        case EventStore.append(event) do
          {:ok, stored} ->
            {:reply, {:ok, Event.ref(stored)}, state}

          {:error, _} = error ->
            {:reply, error, state}
        end

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:inspect_state, _from, state) do
    sanitized = Map.put(state, :keypair, %{public: state.keypair.public})
    {:reply, sanitized, state}
  end
end
