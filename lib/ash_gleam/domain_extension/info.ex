# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.DomainExtension.Info do
  @moduledoc false

  @spec gleam_update_resources(module()) :: [AshGleam.Dsl.GleamUpdateResource.t()]
  def gleam_update_resources(domain) do
    Spark.Dsl.Extension.get_entities(domain, [:gleam_updates])
  end
end
