# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Domain do
  @moduledoc """
  Domain extension for Gleam FFI exports and code interface generation.

  ## Usage

      defmodule MyApp.MyDomain do
        use Ash.Domain,
          otp_app: :my_app,
          extensions: [AshGleam.Domain]

        gleam do
          ffi do
            resource MyApp.Todo do
              action :list_todos, :read
              action :create_todo, :create
            end
          end

          code_interface do
            resource MyApp.Todo do
              define_gleam_update :mark_completed, action: :update
            end
          end
        end
      end
  """

  alias AshGleam.Dsl.{FFIAction, FFIResource, GleamUpdate, GleamUpdateResource}
  alias AshGleam.Transformers.{GenerateDomainInterface, ValidateDomainExtension, ValidateFFI}
  alias Spark.Builder.{Entity, Field, Section}

  # --- FFI entities ---

  @ffi_action Entity.new(:action, FFIAction,
                describe: "Expose an Ash action to generated Gleam FFI.",
                args: [:ffi_name, :action],
                schema: [
                  Field.new(:ffi_name, :atom, required: true),
                  Field.new(:action, :atom, required: true)
                ]
              )
              |> Entity.build!()

  @ffi_resource Entity.new(:resource, FFIResource,
                  describe: "Configure FFI exports for a resource.",
                  args: [:resource],
                  schema: [
                    Field.new(:resource, {:spark, Ash.Resource}, required: true)
                  ],
                  entities: [actions: [@ffi_action]],
                  identifier: :resource
                )
                |> Entity.build!()

  @ffi_section Section.new(:ffi,
                 describe: "Configure generated Gleam FFI wrappers.",
                 entities: [@ffi_resource]
               )
               |> Section.build!()

  # --- Code interface entities ---

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

  @code_interface_section Section.new(:code_interface,
                            describe:
                              "Configure generated domain functions for Gleam update actions.",
                            entities: [@gleam_update_resource]
                          )
                          |> Section.build!()

  # --- Top-level gleam section ---

  @gleam_section Section.new(:gleam,
                   describe: "Configure Gleam FFI and code interface generation for this domain.",
                   sections: [@ffi_section, @code_interface_section]
                 )
                 |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@gleam_section],
    verifiers: [ValidateFFI, ValidateDomainExtension],
    transformers: [GenerateDomainInterface]
end
