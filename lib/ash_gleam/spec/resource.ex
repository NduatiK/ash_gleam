# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Spec.Resource do
  @moduledoc false

  alias AshGleam.Spec.Field

  @enforce_keys [:module, :gleam_type, :module_name, :fields]
  defstruct module: nil, gleam_type: nil, module_name: nil, fields: []

  @type t :: %__MODULE__{
          module: module(),
          gleam_type: String.t(),
          module_name: String.t(),
          fields: [Field.t()]
        }

  def build(resource) do
    %__MODULE__{
      module: resource,
      gleam_type: AshGleam.Resource.Info.gleam_type_name!(resource),
      module_name: AshGleam.Resource.Info.gleam_module_name(resource),
      fields: AshGleam.Resource.Info.field_specs(resource)
    }
  end

  def create_fields(%__MODULE__{fields: fields}) do
    Enum.filter(fields, fn %Field{} = field ->
      not field.primary_key? and field.writable? and not field.generated?
    end)
  end
end
