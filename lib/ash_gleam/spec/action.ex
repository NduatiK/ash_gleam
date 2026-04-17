# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Spec.Action do
  @moduledoc false

  alias AshGleam.Spec.Field

  @enforce_keys [:resource, :action_name, :return_type, :constraints, :arguments, :run]
  defstruct resource: nil,
            action_name: nil,
            return_type: nil,
            constraints: [],
            arguments: [],
            run: nil

  @type t :: %__MODULE__{
          resource: String.t(),
          action_name: atom(),
          return_type: String.t(),
          constraints: Keyword.t(),
          arguments: [Field.t()],
          run: %{module: module(), function: atom(), arity: non_neg_integer()}
        }

  def build(resource, action) do
    info = Function.info(action.run)

    %__MODULE__{
      resource: inspect(resource),
      action_name: action.name,
      return_type: inspect_type(action.return_type),
      constraints: Map.get(action, :constraints, []),
      arguments: Enum.map(action.arguments, &Field.from_argument/1),
      run: %{
        module: Keyword.fetch!(info, :module),
        function: Keyword.fetch!(info, :name),
        arity: Keyword.fetch!(info, :arity)
      }
    }
  end

  defp inspect_type(type), do: inspect(type)
end
