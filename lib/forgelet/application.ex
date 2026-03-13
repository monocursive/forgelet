defmodule Forgelet.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ForgeletWeb.Telemetry,
      Forgelet.Repo,
      {DNSCluster, query: Application.get_env(:forgelet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Forgelet.PubSub},
      Forgelet.Identity.Vault,
      Forgelet.EventStore,
      {Horde.Registry, name: Forgelet.Registry, keys: :unique, members: :auto},
      {Horde.DynamicSupervisor,
       name: Forgelet.AgentSupervisor, strategy: :one_for_one, members: :auto},
      {Horde.DynamicSupervisor,
       name: Forgelet.RepoSupervisor, strategy: :one_for_one, members: :auto},
      Forgelet.Consensus.Engine,
      ForgeletWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Forgelet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ForgeletWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
