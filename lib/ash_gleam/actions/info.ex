# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Actions.Info do
  @moduledoc false

  use Spark.InfoGenerator, extension: AshGleam.Actions, sections: [:gleam_actions]

  @spec actions(module()) :: [AshGleam.Dsl.GleamAction.t()]
  def actions(resource) do
    Spark.Dsl.Extension.get_entities(resource, [:gleam_actions])
  end
end
