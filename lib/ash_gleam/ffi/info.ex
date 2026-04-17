# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.FFI.Info do
  @moduledoc false

  @spec resources(module()) :: [AshGleam.Dsl.FFIResource.t()]
  def resources(domain) do
    Spark.Dsl.Extension.get_entities(domain, [:gleam, :ffi])
  end

  @spec spec(module(), map()) :: AshGleam.Spec.Domain.t()
  def spec(domain, resources), do: AshGleam.Spec.Domain.build(domain, resources)
end
