# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.ValidateResource do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(resource) do
    exported_attributes = Ash.Resource.Info.public_attributes(resource)

    type_name_required = not Enum.empty?(exported_attributes)

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

      true ->
        :ok
    end
  end
end
