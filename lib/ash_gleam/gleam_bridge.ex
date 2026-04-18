# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.GleamBridge.Extension do
  @moduledoc false

  alias AshGleam.Dsl.{BridgeArgument, Consume, ConsumeFunction, Expose, ExposeFunction}
  alias AshGleam.Transformers.{ValidateBridgeConsume, ValidateBridgeExpose}
  alias Spark.Builder.{Entity, Field, Section}

  @argument Entity.new(:argument, BridgeArgument,
              describe: "An argument for a bridge function.",
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

  @consume_function Entity.new(:function, ConsumeFunction,
                      describe: "A Gleam function callable from Elixir.",
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

  @expose_function Entity.new(:function, ExposeFunction,
                     describe: "An Elixir function exposed to Gleam.",
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

  @consume Entity.new(:consume, Consume,
             describe: "Gleam functions callable from Elixir.",
             entities: [functions: [@consume_function]]
           )
           |> Entity.build!()

  @expose Entity.new(:expose, Expose,
            describe: "Elixir functions exposed to Gleam.",
            entities: [functions: [@expose_function]]
          )
          |> Entity.build!()

  @gleam_section Section.new(:gleam,
                   describe: "Configure Elixir↔Gleam function bridging.",
                   patchable?: false,
                   entities: [@consume, @expose]
                 )
                 |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@gleam_section],
    verifiers: [ValidateBridgeConsume, ValidateBridgeExpose],
    transformers: [AshGleam.Transformers.GenerateBridgeInterface]
end

defmodule AshGleam.GleamBridge do
  @moduledoc """
  Standalone DSL for bidirectional Elixir↔Gleam function bridging.

  Exposes Elixir functions to Gleam (`expose`) and makes Gleam functions
  callable from Elixir (`consume`).

      defmodule MyApp.Math do
        use AshGleam.GleamBridge

        gleam do
          consume do
            function :add_in_gleam, :integer do
              argument :a, :integer, allow_nil?: false
              argument :b, :integer, allow_nil?: false

              run &:gleam_module.add/2
            end
          end

          expose do
            function :add_in_elixir, :integer do
              argument :a, :integer, allow_nil?: false
              argument :b, :integer, allow_nil?: false

              run fn a, b -> {:ok, a + b} end
            end
          end
        end
      end
  """

  use Spark.Dsl,
    default_extensions: [extensions: [AshGleam.GleamBridge.Extension]]
end
