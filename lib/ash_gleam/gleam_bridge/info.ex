# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.GleamBridge.Info do
  @moduledoc false

  @spec consume_functions(module()) :: [AshGleam.Dsl.ConsumeFunction.t()]
  def consume_functions(module) do
    module
    |> Spark.Dsl.Extension.get_entities([:gleam])
    |> Enum.flat_map(fn
      %AshGleam.Dsl.Consume{functions: fns} -> List.wrap(fns)
      _ -> []
    end)
  end

  @spec expose_functions(module()) :: [AshGleam.Dsl.ExposeFunction.t()]
  def expose_functions(module) do
    module
    |> Spark.Dsl.Extension.get_entities([:gleam])
    |> Enum.flat_map(fn
      %AshGleam.Dsl.Expose{functions: fns} -> List.wrap(fns)
      _ -> []
    end)
  end
end
