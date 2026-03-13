defmodule Forgelet.RepositoryTest do
  use Forgelet.DataCase

  alias Forgelet.{Repository, EventStore, Identity}

  setup do
    owner = Identity.generate()
    %{owner: owner}
  end

  describe "create/3" do
    test "starts process and publishes repo_created", %{owner: owner} do
      assert {:ok, pid, repo_id} = Repository.create("test-repo", owner)
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert byte_size(repo_id) == 32

      # Allow the async :publish_created message to be processed
      Process.sleep(100)

      events = EventStore.by_kind(:repo_created)
      scoped = Enum.filter(events, fn e -> e.scope == {:repo, repo_id} end)
      assert length(scoped) >= 1

      event = hd(scoped)
      assert event.kind == :repo_created
      assert event.author == owner.public
      assert event.payload["name"] || event.payload[:name]
    end
  end

  describe "get_state/1" do
    test "returns state with name and id", %{owner: owner} do
      {:ok, _pid, repo_id} = Repository.create("state-repo", owner)
      Process.sleep(100)

      state = Repository.get_state(repo_id)
      assert state.name == "state-repo"
      assert state.id == repo_id
      # Owner secret key should be stripped from returned state
      refute Map.has_key?(state.owner, :secret)
      assert state.owner.public == owner.public
    end
  end

  describe "publish_intent/3" do
    test "creates scoped event", %{owner: owner} do
      {:ok, _pid, repo_id} = Repository.create("intent-repo", owner)
      Process.sleep(100)

      agent = Identity.generate()
      payload = %{"title" => "Refactor auth", "description" => "Clean up auth module"}
      assert {:ok, event} = Repository.publish_intent(repo_id, agent, payload)

      Process.sleep(100)

      assert event.kind == :intent_published
      assert event.scope == {:repo, repo_id}
      assert event.author == agent.public

      events = EventStore.by_scope({:repo, repo_id})
      intent_events = Enum.filter(events, fn e -> e.kind == :intent_published end)
      assert length(intent_events) >= 1
    end
  end

  describe "list_local/0" do
    test "returns created repos", %{owner: owner} do
      {:ok, _pid1, repo_id1} = Repository.create("list-repo-1", owner)
      {:ok, _pid2, repo_id2} = Repository.create("list-repo-2", owner)
      Process.sleep(100)

      repos = Repository.list_local()
      repo_ids = Enum.map(repos, & &1.repo_id)

      assert repo_id1 in repo_ids
      assert repo_id2 in repo_ids
    end
  end
end
