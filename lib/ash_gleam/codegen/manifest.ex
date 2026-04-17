# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen.Manifest do
  @moduledoc false

  @spec build(Keyword.t()) :: map()
  def build(opts \\ []) do
    all_resources = AshGleam.Info.resources(opts)

    resources =
      all_resources
      |> Enum.filter(&AshGleam.Resource.Info.ash_gleam_resource?/1)
      |> Map.new(&resource_manifest/1)

    domains =
      opts
      |> AshGleam.Info.domains()
      |> Enum.filter(&(AshGleam.FFI.Info.resources(&1) != []))
      |> Map.new(&domain_manifest(&1, resources))

    actions =
      all_resources
      |> Enum.flat_map(&actions_manifest/1)

    reusable_types =
      all_resources
      |> reusable_type_modules()
      |> Map.new(&reusable_type_manifest/1)

    %{
      resources: resources,
      domains: domains,
      actions: actions,
      reusable_types: reusable_types
    }
  end

  defp resource_manifest(resource) do
    {inspect(resource), AshGleam.Resource.Info.spec(resource)}
  end

  defp domain_manifest(domain, resources) do
    {inspect(domain), AshGleam.FFI.Info.spec(domain, resources)}
  end

  defp actions_manifest(resource) do
    AshGleam.Actions.Info.action_specs(resource)
  end

  defp reusable_type_modules(resources) do
    resources
    |> Enum.flat_map(fn resource ->
      resource_reusable_types(resource) ++ action_reusable_types(resource)
    end)
    |> Enum.uniq()
  end

  defp resource_reusable_types(resource) do
    if AshGleam.Resource.Info.ash_gleam_resource?(resource) do
      resource
      |> AshGleam.Resource.Info.fields()
      |> Enum.flat_map(&AshGleam.TypeMapper.reusable_type_modules(&1.type, &1.constraints))
    else
      []
    end
  end

  defp action_reusable_types(resource) do
    resource
    |> AshGleam.Actions.Info.actions()
    |> Enum.flat_map(fn action ->
      AshGleam.TypeMapper.reusable_type_modules(action.return_type, action.constraints) ++
        Enum.flat_map(action.arguments, fn argument ->
          AshGleam.TypeMapper.reusable_type_modules(argument.type, argument.constraints)
        end)
    end)
  rescue
    _ -> []
  end

  defp reusable_type_manifest(module) do
    {inspect(module), AshGleam.Spec.ReusableType.build(module)}
  end
end
