# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.CodeInterface do
  @moduledoc false

  @spec gleam_update(module(), struct(), atom(), map(), atom(), Keyword.t()) ::
          {:ok, struct()} | {:error, term()}
  def gleam_update(resource, record, gleam_action_name, params, ash_action_name, opts) do
    action_opts =
      opts
      |> Keyword.put_new(:domain, Ash.Resource.Info.domain(resource))

    first_arg_name = first_arg_name!(resource, gleam_action_name)
    action_params = Map.put(params, first_arg_name, record)

    with {:ok, proposed} <- run_gleam_action(resource, gleam_action_name, action_params, action_opts) do
      changes = AshGleam.Diff.resource_changes(record, proposed)

      record
      |> Ash.Changeset.for_update(ash_action_name, changes)
      |> Ash.update(action_opts)
    end
  end

  defp run_gleam_action(resource, action_name, params, opts) do
    resource
    |> Ash.ActionInput.for_action(action_name, params, opts)
    |> Ash.run_action(opts)
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
