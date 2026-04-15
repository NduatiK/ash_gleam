# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Resource.Info do
  @moduledoc false

  use Spark.InfoGenerator, extension: AshGleam.Resource, sections: [:gleam]

  @spec ash_gleam_resource?(module()) :: boolean()
  def ash_gleam_resource?(resource) do
    case gleam_type_name(resource) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @spec gleam_type_name(module()) :: {:ok, String.t()} | :error
  def gleam_type_name(resource) do
    {:ok, gleam_type_name!(resource)}
  rescue
    _ -> :error
  end

  @spec gleam_type_name!(module()) :: String.t()
  def gleam_type_name!(resource) do
    resource
    |> Spark.Dsl.Extension.get_opt([:gleam], :type_name, nil)
    |> case do
      nil -> raise ArgumentError, "#{inspect(resource)} does not use AshGleam.Resource"
      value -> value
    end
  end

  @spec gleam_module_name(module()) :: String.t()
  def gleam_module_name(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:gleam], :module_name, nil) ||
      resource
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
  end

  @spec fields(module()) :: [Ash.Resource.Attribute.t()]
  def fields(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.filter(&AshGleam.TypeMapper.supported?(&1.type))
  end
end
