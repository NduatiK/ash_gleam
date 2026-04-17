# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen do
  @moduledoc false

  alias AshGleam.Codegen.{Manifest, Renderer, Writer}

  @spec run(Keyword.t()) :: :ok
  def run(opts \\ []) do
    manifest = Manifest.build(opts)
    result = Writer.write(manifest, Renderer.render(manifest, opts), opts)

    format_generated_elixir(opts)
    format_generated_gleam(opts)

    result
  end

  def format_generated_elixir(opts) do
    Mix.Task.run("format", [AshGleam.Info.output_dir(opts) <> "/**"])
  end

  def format_generated_gleam(opts) do
    try do
      System.cmd("gleam", ["format", AshGleam.Info.output_dir(opts)])
    rescue
      _ ->
        nil
    end
  end
end
