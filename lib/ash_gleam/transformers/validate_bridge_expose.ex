# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateBridgeExpose do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    dsl_state
    |> AshGleam.GleamBridge.Info.expose_functions()
    |> Enum.reduce_while(:ok, fn func, :ok ->
      with :ok <- validate_type(func.return_type, func.constraints, dsl_state, "return type"),
           :ok <- validate_arguments(func.arguments, dsl_state),
           :ok <- validate_run(func) do
        {:cont, :ok}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_arguments(arguments, dsl_state) do
    Enum.reduce_while(arguments, :ok, fn argument, :ok ->
      case validate_type(argument.type, argument.constraints, dsl_state, "argument #{inspect(argument.name)}") do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_type(type, constraints, dsl_state, label) do
    if AshGleam.TypeMapper.supported?(type, constraints) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: dsl_state,
         message: "Unsupported #{label} #{inspect(type)} with constraints #{inspect(constraints)} in gleam.expose"
       )}
    end
  end

  defp validate_run(func) when is_function(func.run) do
    info = Function.info(func.run)
    arity = Keyword.fetch!(info, :arity)
    expected_arity = length(func.arguments)

    if arity == expected_arity do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: Keyword.get(info, :module),
         message: "`run` fn arity (#{arity}) must match declared argument count (#{expected_arity}) in gleam.expose"
       )}
    end
  end

  defp validate_run(func) do
    {:error,
     Spark.Error.DslError.exception(
       module: func.__spark_metadata__[:module],
       message: "`run` in gleam.expose must be an anonymous function, e.g. `fn a, b -> {:ok, a + b} end`"
     )}
  end
end
