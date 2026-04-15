# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateFFI do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(domain) do
    domain_module = Spark.Dsl.Verifier.get_persisted(domain, :module)

    domain
    |> AshGleam.FFI.Info.resources()
    |> Enum.reduce_while({:ok, MapSet.new()}, fn resource_entry, {:ok, names} ->
      with :ok <- ensure_resource_in_domain(domain_module, resource_entry.resource),
           :ok <- ensure_ash_gleam_resource(resource_entry.resource),
           :ok <- validate_actions(resource_entry, names) do
        names =
          Enum.reduce(resource_entry.actions, names, fn action, acc ->
            MapSet.put(acc, action.ffi_name)
          end)

        {:cont, {:ok, names}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp ensure_resource_in_domain(domain, resource) do
    case Ash.Domain.Info.resource(domain, resource) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp ensure_ash_gleam_resource(resource) do
    if AshGleam.Resource.Info.ash_gleam_resource?(resource) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: resource,
         message:
           "#{inspect(resource)} must use AshGleam.Resource before it can be exported through AshGleam.FFI"
       )}
    end
  end

  defp validate_actions(resource_entry, names) do
    Enum.reduce_while(resource_entry.actions, :ok, fn action_entry, :ok ->
      cond do
        MapSet.member?(names, action_entry.ffi_name) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              module: resource_entry.resource,
              message: "Duplicate gleam_ffi name #{inspect(action_entry.ffi_name)}"
            )}}

        action = Ash.Resource.Info.action(resource_entry.resource, action_entry.action) ->
          if action.type in [:read, :create] or action.name == :get do
            {:cont, :ok}
          else
            {:halt,
             {:error,
              Spark.Error.DslError.exception(
                module: resource_entry.resource,
                message:
                  "FFI action #{inspect(action_entry.action)} must be a :read, :create, or :get action"
              )}}
          end

        true ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              module: resource_entry.resource,
              message: "Unknown Ash action #{inspect(action_entry.action)}"
            )}}
      end
    end)
  end
end
