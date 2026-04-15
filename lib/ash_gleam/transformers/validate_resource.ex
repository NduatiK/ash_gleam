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
      |> Enum.reject(&AshGleam.TypeMapper.supported?(&1.type))

    case unsupported do
      [] ->
        :ok

      attrs ->
        {:error,
         Spark.Error.DslError.exception(
           module: Spark.Dsl.Verifier.get_persisted(resource, :module),
           message:
             "AshGleam.Resource only supports scalar, array, and AshGleam-enabled resource fields. Unsupported fields: #{Enum.map_join(attrs, ", ", &to_string(&1.name))}"
         )}
    end
  end
end
