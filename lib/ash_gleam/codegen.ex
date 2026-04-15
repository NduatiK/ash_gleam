# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen do
  @moduledoc false

  alias AshGleam.Codegen.{Manifest, Renderer, Writer}

  @spec run(Keyword.t()) :: :ok
  def run(opts \\ []) do
    manifest = Manifest.build(opts)
    Writer.write(manifest, Renderer.render(manifest, opts), opts)
  end
end
