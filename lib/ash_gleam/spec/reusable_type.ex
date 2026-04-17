# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Spec.ReusableType do
  @moduledoc false

  alias AshGleam.Spec.Field

  defmodule Variant do
    @moduledoc false

    @enforce_keys [:name, :fields]
    defstruct name: nil, fields: []

    @type t :: %__MODULE__{
            name: atom(),
            fields: [Field.t()]
          }
  end

  @enforce_keys [:module, :kind, :gleam_type, :module_name, :variants]
  defstruct module: nil, kind: nil, gleam_type: nil, module_name: nil, variants: []

  @type t :: %__MODULE__{
          module: module(),
          kind: atom(),
          gleam_type: String.t(),
          module_name: String.t(),
          variants: [Variant.t()]
        }

  def build(module) do
    {:ok, definition} = AshGleam.ReusableType.definition(module)

    %__MODULE__{
      module: module,
      kind: definition.kind,
      gleam_type: definition.gleam_type,
      module_name: definition.module_name,
      variants:
        Enum.map(definition.variants, fn variant ->
          %Variant{name: variant.name, fields: Enum.map(variant.fields, &Field.from_argument/1)}
        end)
    }
  end
end
