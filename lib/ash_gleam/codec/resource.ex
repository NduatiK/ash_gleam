# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codec.Resource do
  @moduledoc false

  @spec to_gleam(module(), struct() | map()) :: tuple()
  def to_gleam(resource, value) do
    constructor =
      resource
      |> AshGleam.Resource.Info.gleam_type_name!()
      |> Macro.underscore()
      |> String.to_atom()

    fields =
      resource
      |> AshGleam.Resource.Info.field_specs()
      |> Enum.map(fn field ->
        field_value = Map.get(value, field.name)

        AshGleam.Marshal.input!(field.type, field_value,
          allow_nil?: field.allow_nil?,
          constraints: field.constraints
        )
      end)

    List.to_tuple([constructor | fields])
  end

  @spec from_gleam(module(), tuple() | struct() | map()) :: map()
  def from_gleam(resource, value)

  def from_gleam(resource, %resource{} = value), do: value

  def from_gleam(resource, value) when is_map(value) do
    build_resource_map(resource, value)
  end

  def from_gleam(resource, value) when is_tuple(value) do
    [_constructor | raw_values] = Tuple.to_list(value)

    resource
    |> AshGleam.Resource.Info.field_specs()
    |> Enum.zip(raw_values)
    |> Enum.reduce(%{}, fn {field, raw}, acc ->
      Map.put(
        acc,
        field.name,
        AshGleam.Marshal.output!(field.type, raw,
          allow_nil?: field.allow_nil?,
          constraints: field.constraints
        )
      )
    end)
    |> build_resource_map(resource)
  end

  defp build_resource_map(resource, values) when is_atom(resource),
    do: build_resource_map(values, resource)

  defp build_resource_map(values, resource) do
    struct(resource, values)
  rescue
    _ -> values
  end
end
