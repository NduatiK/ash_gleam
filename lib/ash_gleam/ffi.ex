# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.FFI do
  @moduledoc """
  Domain extension for exported Gleam FFI actions.
  """

  alias AshGleam.Dsl.{FFIAction, FFIResource}
  alias AshGleam.Transformers.ValidateFFI
  alias Spark.Builder.{Entity, Field, Section}

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

  @ffi_section Section.new(:gleam_ffi,
                 describe: "Configure generated Gleam FFI wrappers.",
                 entities: [@ffi_resource]
               )
               |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@ffi_section],
    verifiers: [ValidateFFI]
end
