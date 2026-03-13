defmodule Forgelet.Schema.Proposal do
  @moduledoc """
  Validates payloads for proposal-related events.
  """

  @doc """
  Validates a proposal event's payload.

  All proposal kinds require `intent_ref`.

  - `:proposal_submitted` — also requires `commit_range` (map with `from` and `to`).
  - `:proposal_updated` — also requires `proposal_ref`.
  - `:proposal_withdrawn` — also requires `proposal_ref`.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate(%{kind: atom(), payload: map()}) :: :ok | {:error, String.t()}
  def validate(%{kind: :proposal_submitted, payload: payload}) do
    with :ok <- require_binary(payload, "intent_ref"),
         :ok <- validate_commit_range(payload) do
      :ok
    end
  end

  def validate(%{kind: :proposal_updated, payload: payload}) do
    with :ok <- require_binary(payload, "intent_ref"),
         :ok <- require_binary(payload, "proposal_ref") do
      :ok
    end
  end

  def validate(%{kind: :proposal_withdrawn, payload: payload}) do
    with :ok <- require_binary(payload, "intent_ref"),
         :ok <- require_binary(payload, "proposal_ref") do
      :ok
    end
  end

  defp validate_commit_range(payload) do
    case Map.get(payload, "commit_range") do
      %{"from" => from, "to" => to} when is_binary(from) and is_binary(to) ->
        :ok

      nil ->
        {:error, "missing required field: commit_range"}

      _ ->
        {:error, "commit_range must be a map with binary \"from\" and \"to\" keys"}
    end
  end

  defp require_binary(payload, key) do
    case Map.get(payload, key) do
      value when is_binary(value) -> :ok
      nil -> {:error, "missing required field: #{key}"}
      _ -> {:error, "#{key} must be a binary"}
    end
  end
end
