# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Resource do
  @moduledoc """
  Resource extension for Gleam metadata.
  """

  alias AshGleam.Transformers.ValidateResource
  alias Spark.Builder.Section

  @gleam_section Section.new(:gleam,
                   describe: "Configure Gleam generation for this resource.",
                   schema: [
                     type_name: [
                       type: :string,
                       required: true,
                       doc: "The generated Gleam type name."
                     ],
                     module_name: [
                       type: :string,
                       doc: "Optional override for the generated Gleam module name."
                     ]
                   ]
                 )
                 |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@gleam_section],
    verifiers: [ValidateResource]
end
