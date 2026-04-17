# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Bridge.Context do
  @moduledoc false

  @allowed_opts [
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
  ]

  def split_from_values(values) do
    case List.last(values) do
      {:some, {:context, _} = ctx} ->
        {Enum.drop(values, -1), context_opts(ctx)}

      _ ->
        {Enum.drop(values, -1), []}
    end
  end

  def extract_from_rest([{:some, {:context, _} = ctx}]), do: context_opts(ctx)
  def extract_from_rest(_), do: []

  defp context_opts(ctx) do
    ctx
    |> AshGleam.Context.to_opts()
    |> to_map()
    |> Map.take(@allowed_opts)
    |> Map.to_list()
  end

  defp to_map(%_{} = value), do: Map.from_struct(value)
  defp to_map(value) when is_map(value), do: value
  defp to_map(value) when is_list(value), do: Map.new(value)
end
