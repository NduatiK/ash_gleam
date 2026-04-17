# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateGleamActions do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(resource) do
    resource
    |> AshGleam.Actions.Info.actions()
    |> Enum.reduce_while(:ok, fn action, :ok ->
      with :ok <- validate_type(action.return_type, action.constraints, resource, "return type"),
           :ok <- validate_arguments(action.arguments, resource),
           :ok <- validate_run(action) do
        {:cont, :ok}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_arguments(arguments, resource) do
    Enum.reduce_while(arguments, :ok, fn argument, :ok ->
      case validate_type(
             argument.type,
             argument.constraints,
             resource,
             "argument #{inspect(argument.name)}"
           ) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_type(type, constraints, resource, label) do
    if AshGleam.TypeMapper.supported?(type, constraints) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: resource,
         message: unsupported_type_message(type, constraints, label)
       )}
    end
  end

  defp unsupported_type_message(type, _constraints, "return type")
       when type in [:atom, Ash.Type.Atom] do
    "Unsupported return type #{inspect(type)} in gleam.actions. Atom return types require constraints like `constraints one_of: [:x, :o, :empty]`."
  end

  defp unsupported_type_message(type, _constraints, label)
       when type in [:atom, Ash.Type.Atom] do
    "Unsupported #{label} #{inspect(type)} in gleam.actions. Atom argument types require constraints like `constraints one_of: [:x, :o, :empty]`."
  end

  defp unsupported_type_message(type, constraints, label) do
    "Unsupported #{label} #{inspect(type)} with constraints #{inspect(constraints)} in gleam.actions"
  end

  defp validate_run(action) when is_function(action.run) do
    info = Function.info(action.run)
    arity = Keyword.fetch!(info, :arity)

    if arity == length(action.arguments) and Keyword.get(info, :type) == :external do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: Keyword.get(info, :module),
         message:
           "`run` (#{inspect(action.run)}) must be a remote function capture whose arity matches the declared arguments"
       )}
    end
  end

  defp validate_run(action) do
    {:error,
     Spark.Error.DslError.exception(
       module: action.__spark_metadata__[:module],
       message:
         "`run` must be declared as a function capture, for example `&:todo.mark_completed/1`"
     )}
  end
end
