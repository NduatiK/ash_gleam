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
    {values, context_opts} = split_context(values)

    params =
      resource
      |> AshGleam.Resource.Info.fields()
      |> maybe_filter_fields(field_names)
      |> Enum.zip(values)
      |> Map.new(fn {field, value} ->
        {field.name, AshGleam.Marshal.output!(field.type, value, allow_nil?: field.allow_nil?)}
      end)

    {params, context_opts}
  end

  def decode_action(builder, arguments) do
    values =
      case arguments do
        [] -> []
        _ -> builder |> Tuple.to_list() |> tl()
      end

    {values, context_opts} = split_context(values)

    params =
      arguments
      |> Enum.zip(values)
      |> Map.new(fn {argument, value} ->
        {argument[:name],
         AshGleam.Marshal.output!(argument[:type], value, allow_nil?: argument[:allow_nil?])}
      end)

    {params, context_opts}
  end

  def apply_read_builder(query, resource, builder) do
    list = Tuple.to_list(builder)
    [_constructor, filters, sorts, limit | rest] = list
    context_opts = extract_context_from_rest(rest)

    query =
      query
      |> maybe_filter(resource, filters)
      |> maybe_sort(resource, sorts)
      |> maybe_limit(limit)

    {query, context_opts}
  end

  defp split_context(values) do
    case List.last(values) do
      {:some, {:context, _} = ctx} ->
        {Enum.drop(values, -1),
         AshGleam.Context.to_opts(ctx)
         |> Map.from_struct()
         |> Map.take([
           :domain,
           :context,
           :authorize?,
           :tenant,
           :scope,
           :actor,
           :skip_unknown_inputs,
           :tracer,
           :private_arguments,
           :load
         ])
         |> Map.to_list()}

      _ ->
        {Enum.drop(values, -1), []}
    end
  end

  defp extract_context_from_rest([{:some, {:context, _} = ctx}]),
    do: AshGleam.Context.to_opts(ctx)

  defp extract_context_from_rest(_), do: []

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

  defp decode_sort({sort, sorter}) when is_atom(sort) and sorter in [:asc, :desc] do
    {sort, sorter}
  end

  defp to_existing_atom(value) when is_atom(value), do: value
  defp to_existing_atom(value), do: String.to_existing_atom(value)

  defp maybe_filter_fields(fields, nil), do: fields
  defp maybe_filter_fields(fields, names), do: Enum.filter(fields, &(&1.name in names))
end
