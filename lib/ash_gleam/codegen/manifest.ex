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
    fields =
      resource
      |> AshGleam.Resource.Info.fields()
      |> Enum.map(fn field ->
        %{
          name: field.name,
          type: field.type,
          constraints: field.constraints,
          allow_nil?: field.allow_nil?,
          primary_key?: field.primary_key?,
          writable?: field.writable?,
          generated?: field.generated?
        }
      end)

    {inspect(resource),
     %{
       module: resource,
       gleam_type: AshGleam.Resource.Info.gleam_type_name!(resource),
       module_name: AshGleam.Resource.Info.gleam_module_name(resource),
       fields: fields
     }}
  end

  defp domain_manifest(domain, resources) do
    ffi =
      domain
      |> AshGleam.FFI.Info.resources()
      |> Enum.flat_map(fn resource_entry ->
        Enum.map(resource_entry.actions, fn action_entry ->
          action = Ash.Resource.Info.action(resource_entry.resource, action_entry.action)

          %{
            resource: inspect(resource_entry.resource),
            resource_module: resource_entry.resource,
            ffi_name: action_entry.ffi_name,
            action: action_entry.action,
            kind: ffi_kind(action),
            returns: Map.get(action, :returns),
            allow_nil?: Map.get(action, :allow_nil?, false),
            resource_gleam_module: resources[inspect(resource_entry.resource)].module_name,
            arguments:
              Enum.map(action.arguments, fn argument ->
                %{
                  name: argument.name,
                  type: argument.type,
                  allow_nil?: argument.allow_nil?
                }
              end)
          }
        end)
      end)

    {inspect(domain), %{module: domain, ffi: ffi}}
  end

  defp actions_manifest(resource) do
    Enum.map(AshGleam.Actions.Info.actions(resource), fn action ->
      info = Function.info(action.run)

      %{
        resource: inspect(resource),
        action_name: action.name,
        return_type: inspect_type(action.return_type),
        constraints: action.constraints,
        arguments:
          Enum.map(action.arguments, fn argument ->
            %{
              name: argument.name,
              type: inspect_type(argument.type),
              constraints: argument.constraints,
              allow_nil?: argument.allow_nil?
            }
          end),
        run: %{
          module: Keyword.fetch!(info, :module),
          function: Keyword.fetch!(info, :name),
          arity: Keyword.fetch!(info, :arity)
        }
      }
    end)
  end

  defp ffi_kind(%{get?: true}), do: :get
  defp ffi_kind(%{type: type}), do: type

  defp inspect_type(type) when is_atom(type), do: inspect(type)
  defp inspect_type(type), do: inspect(type)

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
    {:ok, definition} = AshGleam.ReusableType.definition(module)

    variants =
      Enum.map(definition.variants, fn variant ->
        %{
          name: variant.name,
          fields:
            Enum.map(variant.fields, fn field ->
              %{
                name: field.name,
                type: field.type,
                constraints: field.constraints,
                allow_nil?: field.allow_nil?
              }
            end)
        }
      end)

    {inspect(module),
     %{
       module: module,
       kind: definition.kind,
       gleam_type: definition.gleam_type,
       module_name: definition.module_name,
       variants: variants
     }}
  end
end
