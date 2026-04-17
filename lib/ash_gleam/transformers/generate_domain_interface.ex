# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.GenerateDomainInterface do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    dsl_state
    |> AshGleam.DomainExtension.Info.gleam_update_resources()
    |> Enum.reduce({:ok, dsl_state}, fn resource_entry, {:ok, dsl_state} ->
      Enum.reduce(resource_entry.updates, {:ok, dsl_state}, fn update, {:ok, dsl_state} ->
        gleam_action_name = update.gleam_action || update.name

        {:ok,
         define_domain_interface(
           dsl_state,
           resource_entry.resource,
           update.name,
           gleam_action_name,
           update.action
         )}
      end)
    end)
  end

  defp define_domain_interface(dsl_state, resource, fn_name, gleam_action_name, ash_action_name) do
    fn_name_bang = String.to_atom(Atom.to_string(fn_name) <> "!")

    Transformer.eval(
      dsl_state,
      [
        fn_name: fn_name,
        fn_name_bang: fn_name_bang,
        resource: resource,
        gleam_action_name: gleam_action_name,
        ash_action_name: ash_action_name
      ],
      quote generated: true do
        def unquote(fn_name)(record, params \\ %{}, opts \\ []) do
          AshGleam.CodeInterface.gleam_update(
            unquote(resource),
            record,
            unquote(gleam_action_name),
            params,
            unquote(ash_action_name),
            opts
          )
        end

        def unquote(fn_name_bang)(record, params \\ %{}, opts \\ []) do
          case AshGleam.CodeInterface.gleam_update(
                 unquote(resource),
                 record,
                 unquote(gleam_action_name),
                 params,
                 unquote(ash_action_name),
                 opts
               ) do
            {:ok, result} -> result
            {:error, error} -> raise error
          end
        end
      end
    )
  end
end
