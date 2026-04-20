# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codec.Value do
  @moduledoc false

  def encode({:array, inner}, value, opts) when is_list(value) do
    constraints = Keyword.get(opts, :constraints, [])
    item_constraints = Keyword.get(constraints, :items, [])
    nil_items? = Keyword.get(constraints, :nil_items?, false)

    Enum.map(value, fn item ->
      if nil_items? do
        if is_nil(item),
          do: :none,
          else: {:some, encode(inner, item, constraints: item_constraints)}
      else
        encode(inner, item, constraints: item_constraints)
      end
    end)
  end

  def encode(type, value, opts) when is_atom(type) do
    constraints = Keyword.get(opts, :constraints, [])

    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:scalar, _}} -> value
      {:ok, :dynamic} -> value
      {:ok, {:constrained_atom, _}} -> value
      {:ok, {:reusable_union, _, variants}} -> AshGleam.Codec.Union.encode(value, variants)
      {:ok, {:resource, resource}} -> AshGleam.Codec.Resource.to_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end

  def decode({:array, inner}, value, opts) when is_list(value) do
    constraints = Keyword.get(opts, :constraints, [])
    item_constraints = Keyword.get(constraints, :items, [])
    nil_items? = Keyword.get(constraints, :nil_items?, false)

    Enum.map(value, fn item ->
      if nil_items? do
        case item do
          :none -> nil
          {:some, inner_value} -> decode(inner, inner_value, constraints: item_constraints)
          other -> decode(inner, other, constraints: item_constraints)
        end
      else
        decode(inner, item, constraints: item_constraints)
      end
    end)
  end

  def decode(type, value, opts) when is_atom(type) do
    constraints = Keyword.get(opts, :constraints, [])

    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:scalar, _}} -> value
      {:ok, :dynamic} -> value
      {:ok, {:constrained_atom, _}} -> value
      {:ok, {:reusable_union, _, variants}} -> AshGleam.Codec.Union.decode(value, variants)
      {:ok, {:resource, resource}} -> AshGleam.Codec.Resource.from_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end
end
