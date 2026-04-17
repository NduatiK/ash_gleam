# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateGleamActions do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    dsl_state
    |> AshGleam.Actions.Info.actions()
    |> Enum.reduce_while(:ok, fn action, :ok ->
      with :ok <- validate_type(action.return_type, action.constraints, dsl_state, "return type"),
           :ok <- validate_arguments(action.arguments, dsl_state),
           :ok <- validate_run(action),
           :ok <- validate_update_action(action, dsl_state) do
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

  defp unsupported_type_message(type, constraints, label) when is_atom(type) do
    if Code.ensure_loaded?(type) and function_exported?(type, :variants, 0) do
      "Unsupported #{label} #{inspect(type)} in gleam.actions. Reusable types must be `AshSumType` modules, and their payload types must also be AshGleam-supported. Constraints: #{inspect(constraints)}"
    else
      "Unsupported #{label} #{inspect(type)} with constraints #{inspect(constraints)} in gleam.actions"
    end
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

  defp validate_update_action(%{update?: false}, _dsl_state), do: :ok

  defp validate_update_action(%{update?: true} = action, dsl_state) do
    first_arg = List.first(action.arguments)
    return_type = action.return_type

    first_arg_type = first_arg && first_arg.type

    cond do
      not is_atom(return_type) or not AshGleam.Resource.Info.ash_gleam_resource?(return_type) ->
        {:error,
         Spark.Error.DslError.exception(
           module: dsl_state,
           message:
             "gleam action #{inspect(action.name)} has `update? true` but its return type must be an AshGleam resource, got #{inspect(return_type)}"
         )}

      first_arg == nil or first_arg_type != return_type ->
        {:error,
         Spark.Error.DslError.exception(
           module: dsl_state,
           message:
             "gleam action #{inspect(action.name)} has `update? true` but its first argument must be the same resource as the return type (#{inspect(return_type)})"
         )}

      true ->
        :ok
    end
  end
end
