# SPDX-FileCopyrightText: 2025 ash_gleam contributors <https://github.com/ash-project/ash_gleam/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGleam do
  @moduledoc """
  Ash extensions for Gleam interop and code generation.
  """

  alias AshGleam.Codegen.Manifest

  @spec manifest(Keyword.t()) :: map()
  def manifest(opts \\ []) do
    Manifest.build(opts)
  end

  @spec codegen(Keyword.t()) :: :ok | {:error, term()}
  def codegen(opts \\ []) do
    AshGleam.Codegen.run(opts)
  end

  @spec resource_changes(struct() | map(), struct() | map() | tuple()) :: map()
  def resource_changes(original, proposed) do
    AshGleam.Diff.resource_changes(original, proposed)
  end
end
