# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateResource do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(resource) do
    unsupported =
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(&AshGleam.TypeMapper.supported?(&1.type, &1.constraints))

    type_name_required =
      not (resource
           |> Ash.Resource.Info.public_attributes()
           |> Enum.empty?())

    type_name =
      resource
      |> Spark.Dsl.Extension.get_opt([:gleam], :type_name, nil)

    cond do
      type_name_required and is_nil(type_name) ->
        {:error,
         Spark.Error.DslError.exception(
           module: Spark.Dsl.Verifier.get_persisted(resource, :module),
           message: "An AshGleam.Resource must provide a type_name if the resource has attributes"
         )}

      unsupported == [] ->
        :ok

      true ->
        {:error,
         Spark.Error.DslError.exception(
           module: Spark.Dsl.Verifier.get_persisted(resource, :module),
           message:
             "AshGleam.Resource only supports scalar, constrained atom, array, AshGleam-enabled resource fields, and `AshSumType` modules. Unsupported fields: #{Enum.map_join(unsupported, ", ", &to_string(&1.name))}"
         )}
    end
  end
end
