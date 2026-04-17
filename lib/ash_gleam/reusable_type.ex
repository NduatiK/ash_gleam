# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.ReusableType do
  @moduledoc false

  alias AshSumType.{Field, Variant}

  @spec reusable?(term()) :: boolean()
  def reusable?(type), do: union?(type)

  @spec union?(term()) :: boolean()
  def union?(type) when is_atom(type) do
    case Code.ensure_compiled(type) do
      {:module, _} ->
        function_exported?(type, :variants, 0) and function_exported?(type, :fields, 1)

      _ ->
        false
    end
  end

  def union?(_), do: false

  @spec type_name(module()) :: String.t()
  def type_name(type) do
    type
    |> Module.split()
    |> List.last()
  end

  @spec module_name(module()) :: String.t()
  def module_name(type) do
    type
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
  end

  @spec definition(module()) :: {:ok, map()} | :error
  def definition(type) do
    cond do
      union?(type) ->
        {:ok,
         %{
           module: type,
           kind: :union,
           gleam_type: type_name(type),
           module_name: module_name(type),
           variants: union_variants(type)
         }}

      true ->
        :error
    end
  end

  defp union_variants(type) do
    Enum.map(type.variants(), fn %Variant{name: name, fields: fields} ->
      %{
        name: name,
        fields:
          Enum.map(fields, fn %Field{} = field ->
            %{
              name: field.name,
              type: normalize_variant_type(field.type),
              constraints: field.constraints || [],
              allow_nil?: field.allow_nil?
            }
          end)
      }
    end)
  end

  defp normalize_variant_type({:array, inner}), do: {:array, normalize_variant_type(inner)}
  defp normalize_variant_type(type), do: Ash.Type.get_type(type) || type
end
