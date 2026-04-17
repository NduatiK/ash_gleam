# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Spec.Field do
  @moduledoc false

  @enforce_keys [:name, :type]
  defstruct name: nil,
            type: nil,
            constraints: [],
            allow_nil?: false,
            primary_key?: false,
            writable?: false,
            generated?: false

  @type t :: %__MODULE__{
          name: atom(),
          type: term(),
          constraints: Keyword.t(),
          allow_nil?: boolean(),
          primary_key?: boolean(),
          writable?: boolean(),
          generated?: boolean()
        }

  def from_attribute(attribute) do
    %__MODULE__{
      name: attribute.name,
      type: attribute.type,
      constraints: Map.get(attribute, :constraints, []),
      allow_nil?: Map.get(attribute, :allow_nil?, false),
      primary_key?: Map.get(attribute, :primary_key?, false),
      writable?: Map.get(attribute, :writable?, false),
      generated?: Map.get(attribute, :generated?, false)
    }
  end

  def from_argument(argument) do
    %__MODULE__{
      name: Map.fetch!(argument, :name),
      type: Map.fetch!(argument, :type),
      constraints: Map.get(argument, :constraints, []),
      allow_nil?: Map.get(argument, :allow_nil?, false)
    }
  end
end
