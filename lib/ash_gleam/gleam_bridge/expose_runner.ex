# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.GleamBridge.ExposeRunner do
  @moduledoc false

  def call(module, func_name, named_args) when is_map(named_args) do
    func = find_function!(module, func_name)

    args =
      Enum.map(func.arguments, fn argument ->
        value = Map.get(named_args, argument.name)

        unless argument.allow_nil? or not is_nil(value) do
          raise ArgumentError,
                "argument #{inspect(argument.name)} is required for #{inspect(module)}.#{func_name}"
        end

        value
      end)

    result = apply(func.run, args)

    normalize_result(result)
  end

  defp find_function!(module, func_name) do
    module
    |> AshGleam.GleamBridge.Info.expose_functions()
    |> Enum.find(&(&1.name == func_name))
    |> case do
      nil -> raise ArgumentError, "no expose function #{inspect(func_name)} on #{inspect(module)}"
      func -> func
    end
  end

  defp normalize_result({:ok, value}), do: {:ok, value}
  defp normalize_result({:error, error}) when is_binary(error), do: {:error, error}
  defp normalize_result({:error, error}), do: {:error, inspect(error)}
  defp normalize_result(value), do: {:ok, value}
end
