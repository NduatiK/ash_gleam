# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Bridge.Decode do
  @moduledoc false

  def create(builder, resource, field_names \\ nil) do
    [_constructor | values] = Tuple.to_list(builder)
    {values, context_opts} = AshGleam.Bridge.Context.split_from_values(values)

    params =
      resource
      |> AshGleam.Resource.Info.field_specs()
      |> maybe_filter_fields(field_names)
      |> Enum.zip(values)
      |> Map.new(fn {field, value} ->
        {field.name, decode_value(field.type, value, field.allow_nil?, field.constraints)}
      end)

    {params, context_opts}
  end

  def action(builder, arguments) do
    values =
      case arguments do
        [] -> []
        _ -> builder |> Tuple.to_list() |> tl()
      end

    {values, context_opts} = AshGleam.Bridge.Context.split_from_values(values)

    params =
      arguments
      |> Enum.zip(values)
      |> Map.new(fn {argument, value} ->
        {Map.fetch!(argument, :name),
         decode_value(
           Map.fetch!(argument, :type),
           value,
           Map.get(argument, :allow_nil?, false),
           Map.get(argument, :constraints, [])
         )}
      end)

    {params, context_opts}
  end

  defp decode_value(type, value, allow_nil?, constraints) do
    AshGleam.Marshal.output!(type, value, allow_nil?: allow_nil?, constraints: constraints)
  end

  defp maybe_filter_fields(fields, nil), do: fields
  defp maybe_filter_fields(fields, names), do: Enum.filter(fields, &(&1.name in names))
end
