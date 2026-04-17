# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Marshal do
  @moduledoc false

  alias AshGleam.Error.ActionInterop

  @spec input!(term(), term(), Keyword.t()) :: term()
  def input!(type, value, opts \\ []) do
    if is_nil(value) and Keyword.get(opts, :allow_nil?, true) do
      :none
    else
      marshal(type, value, opts, :to_gleam)
    end
  rescue
    error ->
      raise ActionInterop,
        message: "Failed to marshal input",
        details: %{phase: :marshal_input, type: type, error: Exception.message(error)}
  end

  @spec output!(term(), term(), Keyword.t()) :: term()
  def output!(type, value, opts \\ []) do
    cond do
      value == :none and Keyword.get(opts, :allow_nil?, false) ->
        nil

      match?({:some, _}, value) and Keyword.get(opts, :allow_nil?, false) ->
        {:some, inner} = value
        marshal(type, inner, opts, :from_gleam)

      true ->
        marshal(type, value, opts, :from_gleam)
    end
  rescue
    error ->
      raise ActionInterop,
        message: "Failed to marshal output",
        details: %{phase: :marshal_output, type: type, error: Exception.message(error)}
  end

  @spec to_gleam(module(), struct() | map()) :: tuple()
  def to_gleam(resource, value) do
    constructor =
      resource
      |> AshGleam.Resource.Info.gleam_type_name!()
      |> Macro.underscore()
      |> String.to_atom()

    fields =
      resource
      |> AshGleam.Resource.Info.fields()
      |> Enum.map(fn field ->
        field_value = Map.get(value, field.name)

        input!(field.type, field_value,
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
    |> AshGleam.Resource.Info.fields()
    |> Enum.zip(raw_values)
    |> Enum.reduce(%{}, fn {field, raw}, acc ->
      Map.put(
        acc,
        field.name,
        output!(field.type, raw,
          allow_nil?: field.allow_nil?,
          constraints: field.constraints
        )
      )
    end)
    |> build_resource_map(resource)
  end

  defp marshal(type, value, opts, direction)

  defp marshal({:array, inner}, value, opts, direction) when is_list(value) do
    Enum.map(
      value,
      &marshal(
        inner,
        &1,
        [constraints: Keyword.get(opts, :constraints, []) |> Keyword.get(:items, [])],
        direction
      )
    )
  end

  defp marshal(type, value, opts, :to_gleam) when is_atom(type) do
    constraints = Keyword.get(opts, :constraints, [])

    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:scalar, _}} -> value
      {:ok, {:atom_enum, _}} -> value
      {:ok, {:reusable_union, _, variants}} -> union_to_gleam(value, variants)
      {:ok, {:resource, resource}} -> to_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end

  defp marshal(type, value, opts, :from_gleam) when is_atom(type) do
    constraints = Keyword.get(opts, :constraints, [])

    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:scalar, _}} -> value
      {:ok, {:atom_enum, _}} -> value
      {:ok, {:reusable_union, _, variants}} -> union_from_gleam(value, variants)
      {:ok, {:resource, resource}} -> from_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end

  defp union_to_gleam(value, variants) when is_atom(value) do
    variant = fetch_union_variant!(variants, value)

    case variant.fields do
      [] -> value
      _ -> raise ArgumentError, "expected tuple payload for variant #{inspect(value)}"
    end
  end

  defp union_to_gleam(value, variants) when is_tuple(value) do
    [type | payload] = Tuple.to_list(value)
    variant = fetch_union_variant!(variants, type)
    encoded = encode_union_payload(payload, variant.fields)

    List.to_tuple([type | encoded])
  end

  defp union_to_gleam(value, _variants) do
    raise ArgumentError, "expected atom or tagged tuple for reusable union value, got: #{inspect(value)}"
  end

  defp union_from_gleam(value, variants) when is_atom(value) do
    variant = fetch_union_variant!(variants, value)

    case variant.fields do
      [] -> value
      _ -> raise ArgumentError, "expected tuple payload for variant #{inspect(value)}"
    end
  end

  defp union_from_gleam(value, variants) when is_tuple(value) do
    [type | payload] = Tuple.to_list(value)
    variant = fetch_union_variant!(variants, type)
    decoded = decode_union_payload(payload, variant.fields)

    List.to_tuple([type | decoded])
  end

  defp union_from_gleam(value, _variants) do
    raise ArgumentError, "expected atom or tagged tuple for reusable union value, got: #{inspect(value)}"
  end

  defp encode_union_payload(values, fields) when length(values) == length(fields) do
    Enum.zip_with(values, fields, fn value, field ->
      input!(field.type, value,
        allow_nil?: field.allow_nil?,
        constraints: field.constraints
      )
    end)
  end

  defp encode_union_payload(values, fields) do
    raise ArgumentError,
          "expected #{length(fields)} payload value(s), got #{length(values)}: #{inspect(values)}"
  end

  defp decode_union_payload(values, fields) when length(values) == length(fields) do
    Enum.zip_with(values, fields, fn value, field ->
      output!(field.type, value,
        allow_nil?: field.allow_nil?,
        constraints: field.constraints
      )
    end)
  end

  defp decode_union_payload(values, fields) do
    raise ArgumentError,
          "expected #{length(fields)} payload value(s), got #{length(values)}: #{inspect(values)}"
  end

  defp fetch_union_variant!(variants, type) do
    Enum.find(variants, &(&1.name == type)) ||
      raise ArgumentError, "unknown union variant #{inspect(type)}"
  end

  defp build_resource_map(resource, values) when is_atom(resource),
    do: build_resource_map(values, resource)

  defp build_resource_map(values, resource) do
    struct(resource, values)
  rescue
    _ -> values
  end
end
