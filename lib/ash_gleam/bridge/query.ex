# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Bridge.Query do
  @moduledoc false

  def apply_read_builder(query, _resource, builder) do
    [_constructor, filters, sorts, limit | rest] = Tuple.to_list(builder)
    context_opts = AshGleam.Bridge.Context.extract_from_rest(rest)

    query =
      query
      |> maybe_filter(filters)
      |> maybe_sort(sorts)
      |> maybe_limit(limit)

    {query, context_opts}
  end

  defp maybe_filter(query, []), do: query

  defp maybe_filter(query, filters) do
    filters
    |> Enum.map(&decode_filter/1)
    |> Enum.reject(&is_nil/1)
    |> then(&Ash.Query.filter_input(query, &1))
  end

  defp maybe_sort(query, []), do: query
  defp maybe_sort(query, sorts), do: Ash.Query.sort_input(query, Enum.map(sorts, &decode_sort/1))

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
end
