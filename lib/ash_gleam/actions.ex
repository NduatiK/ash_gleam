# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Actions do
  @moduledoc """
  Resource extension for Gleam-backed Ash actions.
  """

  alias AshGleam.Dsl.{GleamAction, GleamArgument}
  alias AshGleam.Transformers.{GenerateManualActions, ValidateGleamActions}
  alias Spark.Builder.{Entity, Field, Section}

  @argument Entity.new(:argument, GleamArgument,
              describe: "A Gleam-backed action argument.",
              args: [:name, :type],
              schema: [
                Field.new(:name, :atom, required: true),
                Field.new(:type, :any, required: true),
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
              Field.new(:run, :any, required: true),
              Field.new(:allow_nil?, :boolean, default: false)
            ],
            entities: [arguments: [@argument]],
            identifier: :name
          )
          |> Entity.build!()

  @section Section.new(:gleam_actions,
             describe: "Configure Ash actions backed by compiled Gleam functions.",
             entities: [@action]
           )
           |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@section],
    verifiers: [ValidateGleamActions],
    transformers: [GenerateManualActions]
end
