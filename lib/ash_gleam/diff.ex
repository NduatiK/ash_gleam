# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Diff do
  @moduledoc """
  Computes persistable Ash attribute changes from a proposed resource state.
  """

  @spec resource_changes(struct() | map(), struct() | map() | tuple()) :: map()
  def resource_changes(original, proposed) when is_map(original) do
    resource = resource_module!(original)
    proposed = normalize_proposed(resource, proposed)

    resource
    |> persistable_fields()
    |> Enum.reduce(%{}, fn field, changes ->
      original_value = Map.get(original, field.name)
      proposed_value = Map.get(proposed, field.name)

      if original_value == proposed_value do
        changes
      else
        Map.put(changes, field.name, proposed_value)
      end
    end)
  end

  defp normalize_proposed(resource, %{__struct__: struct} = proposed) when struct == resource,
    do: proposed

  defp normalize_proposed(resource, proposed), do: AshGleam.Marshal.from_gleam(resource, proposed)

  defp resource_module!(%{__struct__: resource}) when is_atom(resource), do: resource

  defp resource_module!(_value) do
    raise ArgumentError, "resource_changes/2 expects the original value to be a resource struct"
  end

  defp persistable_fields(resource) do
    resource
    |> AshGleam.Resource.Info.fields()
    |> Enum.filter(&(not &1.primary_key? and &1.writable? and not &1.generated?))
  end
end
