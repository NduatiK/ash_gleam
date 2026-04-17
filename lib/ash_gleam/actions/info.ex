# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Actions.Info do
  @moduledoc false

  use Spark.InfoGenerator, extension: AshGleam.Actions, sections: [:gleam, :actions]

  @spec actions(module()) :: [AshGleam.Dsl.GleamAction.t()]
  def actions(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:gleam])
    |> Enum.flat_map(fn
      %AshGleam.Dsl.GleamActions{actions: actions} -> List.wrap(actions)
      _ -> []
    end)
  end

  @spec action_specs(module()) :: [AshGleam.Spec.Action.t()]
  def action_specs(resource) do
    Enum.map(actions(resource), &AshGleam.Spec.Action.build(resource, &1))
  end
end
