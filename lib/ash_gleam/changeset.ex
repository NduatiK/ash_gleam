# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Changeset do
  @moduledoc """
  Builds an `Ash.Changeset` from a Gleam update-style action without persisting.
  """

  @doc """
  Runs a Gleam action marked `update? true` and returns an `Ash.Changeset` ready for persistence.

  ## Options

    * `:action` (required) - the Ash update action to build the changeset with

  ## Example

      todo
      |> AshGleam.Changeset.for_update(:mark_completed, %{}, action: :update)
      |> Ash.update!()
  """
  @spec for_update(struct(), atom(), map(), Keyword.t()) ::
          {:ok, Ash.Changeset.t()} | {:error, term()}
  def for_update(record, gleam_action_name, params \\ %{}, opts) do
    ash_action_name = Keyword.fetch!(opts, :action)
    resource = record.__struct__

    fetch_update_action!(resource, gleam_action_name)

    with {:ok, proposed} <- invoke_gleam_action(resource, gleam_action_name, record, params, opts) do
      changes = AshGleam.Diff.resource_changes(record, proposed)

      changeset_opts =
        opts
        |> Keyword.drop([:action])
        |> Keyword.put_new(:domain, Ash.Resource.Info.domain(resource))

      {:ok, Ash.Changeset.for_update(record, ash_action_name, changes, changeset_opts)}
    end
  end

  defp fetch_update_action!(resource, gleam_action_name) do
    gleam_action =
      resource
      |> AshGleam.Actions.Info.actions()
      |> Enum.find(&(&1.name == gleam_action_name))

    cond do
      gleam_action == nil ->
        raise ArgumentError,
              "gleam action #{inspect(gleam_action_name)} does not exist on #{inspect(resource)}"

      not gleam_action.update? ->
        raise ArgumentError,
              "gleam action #{inspect(gleam_action_name)} on #{inspect(resource)} is not marked `update? true`"

      true ->
        gleam_action
    end
  end

  defp invoke_gleam_action(resource, gleam_action_name, record, extra_params, opts) do
    action_opts =
      opts
      |> Keyword.drop([:action])
      |> Keyword.put_new(:domain, Ash.Resource.Info.domain(resource))

    params = Map.put(extra_params, first_arg_name!(resource, gleam_action_name), record)

    resource
    |> Ash.ActionInput.for_action(gleam_action_name, params, action_opts)
    |> Ash.run_action(action_opts)
  end

  defp first_arg_name!(resource, gleam_action_name) do
    resource
    |> AshGleam.Actions.Info.actions()
    |> Enum.find(&(&1.name == gleam_action_name))
    |> Map.fetch!(:arguments)
    |> List.first()
    |> Map.fetch!(:name)
  end
end
