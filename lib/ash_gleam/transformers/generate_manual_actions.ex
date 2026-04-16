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
    |> Spark.Dsl.Transformer.get_entities([:gleam_actions])
    |> Enum.reduce_while({:ok, dsl_state}, fn action, {:ok, dsl_state} ->
      
      case build_action(action, resource) do
        {:ok, ash_action} ->
          dsl_state =
            dsl_state
            |> Transformer.add_entity([:actions], ash_action, type: :append)
            |> define_resource_interface(action.name)

          {:cont, {:ok, dsl_state}}

        {:error, error} ->
          IO.inspect({:error, error})
          {:halt, {:error, error}}
      end
    end)
  end

  defp build_action(action, resource) do
    {action.return_type, resource}|> IO.inspect(label: "all")
    with {:ok, args} <- build_arguments(action.arguments, resource),
         {:ok, {return_type, constraints}} <- (ash_type(action.return_type, resource) |> IO.inspect(label: "ash_type")) do
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
    end
  end

  defp build_arguments(arguments, resource) do
    Enum.reduce_while(arguments, {:ok, []}, fn argument, {:ok, built} ->
      case ash_type(argument.type, resource) |> IO.inspect(label: "build_arguments") do
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
            {:ok, entity} -> {:cont, {:ok, built ++ [entity]}}
            {:error, error} ->
              IO.inspect({:error, error})
              {:halt, {:error, error}}
          end

        :error ->
          {:halt, {:error, "unsupported argument type #{inspect(argument.type)}"}}
      end
    end)
  end

  defp ash_type(type, resource) when type == resource do
    {:ok, {:struct, [instance_of: resource]}}
  end

  defp ash_type(type, _resource), do: AshGleam.TypeMapper.ash_type(type)

  defp define_resource_interface(dsl_state, action_name) do
    Transformer.eval(
      dsl_state,
      [action_name: action_name],
      quote generated: true do
        if Module.defines?(__MODULE__, {unquote(action_name), 1}, :def) or
             Module.defines?(__MODULE__, {unquote(action_name), 2}, :def) do
          raise ArgumentError,
                "cannot define #{inspect(unquote(action_name))}/1-2 for gleam_actions because the function already exists on #{inspect(__MODULE__)}"
        end

        def unquote(action_name)(params), do: unquote(action_name)(params, [])

        def unquote(action_name)(params, opts) when is_map(params) and is_list(opts) do
          opts = Keyword.put_new(opts, :domain, Ash.Resource.Info.domain(__MODULE__))

          __MODULE__
          |> Ash.ActionInput.for_action(unquote(action_name), params, opts)
          |> Ash.run_action(opts)
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
      allow_nil?: action.allow_nil?,
      arguments:
        Enum.map(action.arguments, fn argument ->
          %{
            name: argument.name,
            type: argument.type,
            allow_nil?: argument.allow_nil?
          }
        end)
    }
  end
end
