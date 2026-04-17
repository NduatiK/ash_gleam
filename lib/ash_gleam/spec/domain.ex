# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Spec.Domain do
  @moduledoc false

  alias AshGleam.Spec.Field

  @enforce_keys [:module, :ffi]
  defstruct module: nil, ffi: []

  defmodule FFI do
    @moduledoc false

    @enforce_keys [:resource, :resource_module, :ffi_name, :action, :kind]
    defstruct resource: nil,
              resource_module: nil,
              ffi_name: nil,
              action: nil,
              kind: nil,
              returns: nil,
              allow_nil?: false,
              resource_gleam_module: nil,
              arguments: []

    @type t :: %__MODULE__{
            resource: String.t(),
            resource_module: module(),
            ffi_name: atom(),
            action: atom(),
            kind: atom(),
            returns: term(),
            allow_nil?: boolean(),
            resource_gleam_module: String.t(),
            arguments: [Field.t()]
          }
  end

  def build(domain, resources) do
    ffi =
      domain
      |> AshGleam.FFI.Info.resources()
      |> Enum.flat_map(fn resource_entry ->
        Enum.map(resource_entry.actions, fn action_entry ->
          action = Ash.Resource.Info.action(resource_entry.resource, action_entry.action)

          %FFI{
            resource: inspect(resource_entry.resource),
            resource_module: resource_entry.resource,
            ffi_name: action_entry.ffi_name,
            action: action_entry.action,
            kind: ffi_kind(action),
            returns: Map.get(action, :returns),
            allow_nil?: Map.get(action, :allow_nil?, false),
            resource_gleam_module: resources[inspect(resource_entry.resource)].module_name,
            arguments: Enum.map(action.arguments, &Field.from_argument/1)
          }
        end)
      end)

    %__MODULE__{module: domain, ffi: ffi}
  end

  @type t :: %__MODULE__{
          module: module(),
          ffi: [FFI.t()]
        }

  defp ffi_kind(%{get?: true}), do: :get
  defp ffi_kind(%{type: type}), do: type
end
