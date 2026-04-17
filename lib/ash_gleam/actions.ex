# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Actions do
  @moduledoc """
  Resource extension for Gleam-backed Ash actions.
  """

  alias AshGleam.Dsl.{GleamAction, GleamActions, GleamArgument}
  alias AshGleam.Transformers.{GenerateManualActions, ValidateGleamActions}
  alias Spark.Builder.{Entity, Field}
  alias Spark.Dsl.Patch.AddEntity

  @argument Entity.new(:argument, GleamArgument,
              describe: "A Gleam-backed action argument.",
              args: [:name, :type],
              schema: [
                Field.new(:name, :atom, required: true),
                Field.new(:type, :any, required: true),
                Field.new(:constraints, :keyword_list, default: []),
                Field.new(:allow_nil?, :boolean, default: true)
              ],
              identifier: :name
            )
            |> Entity.build!()

  @action Entity.new(:action, GleamAction,
            describe: "A Gleam-backed Ash action.",
            args: [:name, :return_type],
            schema: [
              Field.new(:name, :atom, required: true),
              Field.new(:return_type, :any, required: true),
              Field.new(:constraints, :keyword_list, default: []),
              Field.new(:run, :any, required: true),
              Field.new(:allow_nil?, :boolean, default: false)
            ],
            entities: [arguments: [@argument]],
            identifier: :name
          )
          |> Entity.build!()

  @actions Entity.new(:actions, GleamActions,
             describe: "Configure Ash actions backed by compiled Gleam functions.",
             # entities: [actions: [@action]]
             entities: [actions: [@action]]
           )
           |> Entity.build!()

  @gleam_actions_patch %AddEntity{section_path: [:gleam], entity: @actions}

  use Spark.Dsl.Extension,
    dsl_patches: [@gleam_actions_patch],
    add_extensions: [AshGleam.Resource],
    verifiers: [ValidateGleamActions],
    transformers: [GenerateManualActions]
end
