# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Generated.Bridge do
  @moduledoc false

  def encode_result({:ok, value}, encoder), do: {:ok, encoder.(value)}

  def encode_result({:error, error}, _encoder),
    do: {:error, Exception.message(Ash.Error.to_error_class(error))}

  def encode_result(value, encoder), do: {:ok, encoder.(value)}

  def decode_create(builder, resource, field_names \\ nil) do
    [_constructor | values] = Tuple.to_list(builder)

    resource
    |> AshGleam.Resource.Info.fields()
    |> maybe_filter_fields(field_names)
    |> Enum.zip(values)
    |> Map.new(fn {field, value} ->
      {field.name, AshGleam.Marshal.output!(field.type, value, allow_nil?: field.allow_nil?)}
    end)
  end

  def decode_get(builder) do
    {_constructor, id} = builder
    id
  end

  def apply_read_builder(query, resource, builder) do
    {_constructor, filters, sorts, limit} = builder

    query
    |> maybe_filter(resource, filters)
    |> maybe_sort(resource, sorts)
    |> maybe_limit(limit)
  end

  defp maybe_filter(query, _resource, []), do: query

  defp maybe_filter(query, _resource, filters) do
    filters
    |> Enum.map(&decode_filter/1)
    |> Enum.reject(&is_nil/1)
    |> then(&Ash.Query.filter_input(query, &1))
  end

  defp maybe_sort(query, _resource, []), do: query

  defp maybe_sort(query, _resource, sorts),
    do: Ash.Query.sort_input(query, Enum.map(sorts, &decode_sort/1))

  defp maybe_limit(query, :none), do: query
  defp maybe_limit(query, {:some, limit}), do: Ash.Query.limit(query, limit)
  defp maybe_limit(query, nil), do: query

  defp decode_filter({name, value}) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.trim_trailing("_eq")
    |> to_existing_atom()
    |> then(&[{&1, [eq: value]}])
  end

  defp decode_filter(_), do: nil

  defp decode_sort(sort) when is_atom(sort) do
    sort
    |> Atom.to_string()
    |> case do
      value ->
        cond do
          String.ends_with?(value, "_asc") ->
            {value |> String.trim_trailing("_asc") |> to_existing_atom(), :asc}

          String.ends_with?(value, "_desc") ->
            {value |> String.trim_trailing("_desc") |> to_existing_atom(), :desc}
        end
    end
  end

  defp to_existing_atom(value) when is_atom(value), do: value
  defp to_existing_atom(value), do: String.to_existing_atom(value)

  defp maybe_filter_fields(fields, nil), do: fields
  defp maybe_filter_fields(fields, names), do: Enum.filter(fields, &(&1.name in names))
end
