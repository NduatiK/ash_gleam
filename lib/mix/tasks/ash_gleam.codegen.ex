# SPDX-FileCopyrightText: 2025 ash_gleam contributors <https://github.com/NduatiK/ash_gleam/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.AshGleam.Codegen do
  @moduledoc false
  use Mix.Task

  def run(args) do
    Mix.Tasks.Ash.Gleam.Codegen.run(args)
  end
end

defmodule Mix.Tasks.Ash.Gleam.Codegen do
  @moduledoc """
  Generates Gleam types, FFI wrappers, and Elixir bridge modules for AshGleam.
  """

  use Mix.Task

  @shortdoc "Generate Gleam and Elixir interop files for AshGleam"

  @switches [
    output: :string,
    manifest: :string,
    elixir_output: :string,
    otp_app: :string
  ]

  def run(args) do
    Mix.Task.run("compile")

    {opts, _, _} = OptionParser.parse(args, strict: @switches)

    opts =
      opts
      |> Keyword.update(:otp_app, nil, &String.to_atom/1)

    AshGleam.codegen(opts)
    Mix.Task.run("compile")
  end
end
