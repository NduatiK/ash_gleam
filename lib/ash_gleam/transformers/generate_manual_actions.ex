# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.GenerateManualActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    resource = Transformer.get_persisted(dsl_state, :module)

    dsl_state
    |> AshGleam.Actions.Info.actions()
    |> Enum.reduce_while({:ok, dsl_state}, fn action, {:ok, dsl_state} ->
      case build_action(action, resource) do
        {:ok, ash_action} ->
          dsl_state =
            dsl_state
            |> Transformer.add_entity([:actions], ash_action, type: :append)
            |> define_resource_interface(action.name)

          {:cont, {:ok, dsl_state}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp build_action(action, resource) do
    with {:ok, args} <- build_arguments(action.arguments, resource) do
      case ash_type(action.return_type, action.constraints, resource) do
        {:ok, {return_type, constraints}} ->
          Transformer.build_entity(
            Ash.Resource.Dsl,
            [:actions],
            :action,
            name: action.name,
            returns: return_type,
            constraints: constraints,
            allow_nil?: action.allow_nil?,
            arguments: args,
            run: {AshGleam.ManualActionRunner, [config: runtime_config(action)]}
          )

        :error ->
          {:error, unsupported_type_message(action.return_type, action.constraints, :return)}
      end
    end
  end

  defp build_arguments(arguments, resource) do
    Enum.reduce_while(arguments, {:ok, []}, fn argument, {:ok, built} ->
      case ash_type(argument.type, argument.constraints, resource) do
        {:ok, {type, constraints}} ->
          case Transformer.build_entity(
                 Ash.Resource.Dsl,
                 [:actions, :action],
                 :argument,
                 name: argument.name,
                 type: type,
                 constraints: constraints,
                 allow_nil?: argument.allow_nil?
               ) do
            {:ok, entity} ->
              {:cont, {:ok, built ++ [entity]}}

            {:error, error} ->
              {:halt, {:error, error}}
          end

        :error ->
          {:halt,
           {:error, unsupported_type_message(argument.type, argument.constraints, :argument)}}
      end
    end)
  end

  defp ash_type(type, _constraints, resource) when type == resource do
    {:ok, {:struct, [instance_of: resource]}}
  end

  defp ash_type(type, constraints, _resource), do: AshGleam.TypeMapper.ash_type(type, constraints)

  defp unsupported_type_message(type, constraints, kind)

  defp unsupported_type_message(type, _constraints, :return)
       when type in [:atom, Ash.Type.Atom] do
    "unsupported return type #{inspect(type)}; atom return types require constraints like `constraints one_of: [:x, :o, :empty]`"
  end

  defp unsupported_type_message(type, _constraints, :argument)
       when type in [:atom, Ash.Type.Atom] do
    "unsupported argument type #{inspect(type)}; atom argument types require constraints like `constraints one_of: [:x, :o, :empty]`"
  end

  defp unsupported_type_message(type, constraints, kind) when is_atom(type) do
    label =
      case kind do
        :return -> "return type"
        :argument -> "argument type"
      end

    if Code.ensure_loaded?(type) and function_exported?(type, :variants, 0) do
      "unsupported #{label} #{inspect(type)}; reusable types must be `AshSumType` modules, and their payload types must also be AshGleam-supported. constraints: #{inspect(constraints)}"
    else
      "unsupported #{label} #{inspect(type)} with constraints #{inspect(constraints)}"
    end
  end

  defp unsupported_type_message(type, constraints, kind) do
    label =
      case kind do
        :return -> "return type"
        :argument -> "argument type"
      end

    "unsupported #{label} #{inspect(type)} with constraints #{inspect(constraints)}"
  end

  defp define_resource_interface(dsl_state, action_name) do
    action_name_bang = String.to_atom(Atom.to_string(action_name) <> "!")

    Transformer.eval(
      dsl_state,
      [action_name: action_name, action_name_bang: action_name_bang],
      quote generated: true do
        if Module.defines?(__MODULE__, {unquote(action_name), 1}, :def) or
             Module.defines?(__MODULE__, {unquote(action_name), 2}, :def) do
          raise ArgumentError,
                "cannot define #{inspect(unquote(action_name))}/1-2 for gleam.actions because the function already exists on #{inspect(__MODULE__)}"
        end

        def unquote(action_name)(params), do: unquote(action_name)(params, [])

        def unquote(action_name)(params, opts) when is_map(params) and is_list(opts) do
          opts = Keyword.put_new(opts, :domain, Ash.Resource.Info.domain(__MODULE__))

          __MODULE__
          |> Ash.ActionInput.for_action(unquote(action_name), params, opts)
          |> Ash.run_action(opts)
        end

        def unquote(action_name_bang)(params),
          do: unquote(action_name_bang)(params, [])

        def unquote(action_name_bang)(params, opts)
            when is_map(params) and is_list(opts) do
          opts = Keyword.put_new(opts, :domain, Ash.Resource.Info.domain(__MODULE__))

          __MODULE__
          |> Ash.ActionInput.for_action(unquote(action_name), params, opts)
          |> Ash.run_action!(opts)
        end
      end
    )
  end

  defp runtime_config(action) do
    info = Function.info(action.run)

    %{
      run: %{
        module: Keyword.fetch!(info, :module),
        function: Keyword.fetch!(info, :name),
        arity: Keyword.fetch!(info, :arity)
      },
      return_type: action.return_type,
      constraints: action.constraints,
      allow_nil?: action.allow_nil?,
      pass_context?: action.pass_context?,
      arguments:
        Enum.map(action.arguments, fn argument ->
          %{
            name: argument.name,
            type: argument.type,
            constraints: argument.constraints,
            allow_nil?: argument.allow_nil?
          }
        end)
    }
  end
end
