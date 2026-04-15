# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen.Writer do
  @moduledoc false

  @spec write(map(), map(), Keyword.t()) :: :ok
  def write(manifest, rendered, opts) do
    File.mkdir_p!(AshGleam.Info.output_dir(opts))
    File.mkdir_p!(AshGleam.Info.elixir_output_dir(opts))
    File.mkdir_p!(Path.dirname(AshGleam.Info.manifest_path(opts)))

    Enum.each(rendered.gleam, fn file ->
      File.write!(Path.join(AshGleam.Info.output_dir(opts), file.path), file.contents)
    end)

    Enum.each(rendered.elixir, fn file ->
      path = Path.join(AshGleam.Info.elixir_output_dir(opts), file.path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, file.contents)
    end)

    File.write!(AshGleam.Info.manifest_path(opts), :erlang.term_to_binary(manifest))
    :ok
  end
end
