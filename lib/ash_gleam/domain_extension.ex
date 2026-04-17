# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.DomainExtension do
  @moduledoc """
  Domain extension that generates code-interface functions for Gleam update actions.

  ## Usage

      defmodule MyApp.MyDomain do
        use Ash.Domain,
          otp_app: :my_app,
          extensions: [AshGleam.DomainExtension]

        gleam_updates do
          resource MyApp.Todo do
            define_gleam_update :mark_completed, action: :update
          end
        end
      end

  This generates `mark_completed/1-3` and `mark_completed!/1-3` on the domain module.
  """

  alias AshGleam.Dsl.{GleamUpdate, GleamUpdateResource}
  alias AshGleam.Transformers.{GenerateDomainInterface, ValidateDomainExtension}
  alias Spark.Builder.{Entity, Field, Section}

  @gleam_update Entity.new(:define_gleam_update, GleamUpdate,
                  describe: "Generate a domain function backed by a Gleam update action.",
                  args: [:name],
                  schema: [
                    Field.new(:name, :atom, required: true),
                    Field.new(:action, :atom, required: true),
                    Field.new(:gleam_action, :atom, required: false)
                  ],
                  identifier: :name
                )
                |> Entity.build!()

  @gleam_update_resource Entity.new(:resource, GleamUpdateResource,
                           describe: "Resource-level gleam update interface definitions.",
                           args: [:resource],
                           schema: [
                             Field.new(:resource, {:spark, Ash.Resource}, required: true)
                           ],
                           entities: [updates: [@gleam_update]],
                           identifier: :resource
                         )
                         |> Entity.build!()

  @gleam_updates_section Section.new(:gleam_updates,
                           describe:
                             "Configure generated domain functions for Gleam update actions.",
                           entities: [@gleam_update_resource]
                         )
                         |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@gleam_updates_section],
    verifiers: [ValidateDomainExtension],
    transformers: [GenerateDomainInterface]
end
