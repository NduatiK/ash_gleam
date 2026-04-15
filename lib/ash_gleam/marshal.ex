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
        input!(field.type, field_value, allow_nil?: field.allow_nil?)
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
      Map.put(acc, field.name, output!(field.type, raw, allow_nil?: field.allow_nil?))
    end)
    |> build_resource_map(resource)
  end

  defp marshal(type, value, opts, direction)

  defp marshal({:array, inner}, value, _opts, direction) when is_list(value) do
    Enum.map(value, &marshal(inner, &1, [], direction))
  end

  defp marshal(type, value, _opts, :to_gleam) when is_atom(type) do
    case AshGleam.TypeMapper.normalize(type) do
      {:ok, {:scalar, _}} -> value
      {:ok, {:resource, resource}} -> to_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end

  defp marshal(type, value, _opts, :from_gleam) when is_atom(type) do
    case AshGleam.TypeMapper.normalize(type) do
      {:ok, {:scalar, _}} -> value
      {:ok, {:resource, resource}} -> from_gleam(resource, value)
      :error -> raise ArgumentError, "unsupported type #{inspect(type)}"
    end
  end

  defp build_resource_map(resource, values) when is_atom(resource),
    do: build_resource_map(values, resource)

  defp build_resource_map(values, resource) do
    struct(resource, values)
  rescue
    _ -> values
  end
end
