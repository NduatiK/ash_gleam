# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateDomainExtension do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(domain) do
    domain_module = Spark.Dsl.Verifier.get_persisted(domain, :module)

    domain
    |> AshGleam.DomainExtension.Info.gleam_update_resources()
    |> Enum.reduce_while({:ok, MapSet.new()}, fn resource_entry, {:ok, names} ->
      with :ok <- ensure_resource_in_domain(domain_module, resource_entry.resource),
           :ok <- ensure_ash_gleam_resource(resource_entry.resource),
           {:ok, names} <- validate_updates(resource_entry, names) do
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
           "#{inspect(resource)} must use AshGleam.Actions before it can be used with AshGleam.DomainExtension"
       )}
    end
  end

  defp validate_updates(resource_entry, names) do
    Enum.reduce_while(resource_entry.updates, {:ok, names}, fn update, {:ok, names} ->
      gleam_action_name = update.gleam_action || update.name

      with :ok <- ensure_no_name_collision(update.name, names, resource_entry.resource),
           {:ok, gleam_action} <-
             fetch_gleam_action(resource_entry.resource, gleam_action_name),
           :ok <- ensure_update_action(gleam_action, resource_entry.resource),
           :ok <- ensure_ash_update_action(resource_entry.resource, update.action) do
        {:cont, {:ok, MapSet.put(names, update.name)}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp ensure_no_name_collision(name, names, resource) do
    if MapSet.member?(names, name) do
      {:error,
       Spark.Error.DslError.exception(
         module: resource,
         message: "Duplicate gleam update function name #{inspect(name)}"
       )}
    else
      :ok
    end
  end

  defp fetch_gleam_action(resource, gleam_action_name) do
    case Enum.find(AshGleam.Actions.Info.actions(resource), &(&1.name == gleam_action_name)) do
      nil ->
        {:error,
         Spark.Error.DslError.exception(
           module: resource,
           message:
             "Gleam action #{inspect(gleam_action_name)} does not exist on #{inspect(resource)}"
         )}

      action ->
        {:ok, action}
    end
  end

  defp ensure_update_action(gleam_action, resource) do
    if gleam_action.update? do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: resource,
         message:
           "Gleam action #{inspect(gleam_action.name)} on #{inspect(resource)} must be marked `update? true` to use with define_gleam_update"
       )}
    end
  end

  defp ensure_ash_update_action(resource, action_name) do
    case Ash.Resource.Info.action(resource, action_name) do
      nil ->
        {:error,
         Spark.Error.DslError.exception(
           module: resource,
           message: "Ash action #{inspect(action_name)} does not exist on #{inspect(resource)}"
         )}

      %{type: :update} ->
        :ok

      action ->
        {:error,
         Spark.Error.DslError.exception(
           module: resource,
           message:
             "Ash action #{inspect(action.name)} on #{inspect(resource)} must be an update action, got #{inspect(action.type)}"
         )}
    end
  end
end
