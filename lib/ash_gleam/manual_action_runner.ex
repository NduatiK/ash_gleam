# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.ManualActionRunner do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  def run(input, opts, _context) do
    config = Keyword.fetch!(opts, :config)

    args =
      Enum.map(config.arguments, fn argument ->
        value = Map.get(input.arguments, argument.name)
        AshGleam.Marshal.input!(argument.type, value, allow_nil?: argument.allow_nil?)
      end)

    result =
      AshGleam.Interop.call!(
        config.run.module,
        config.run.function,
        args,
        resource: input.resource,
        action: input.action.name
      )

    {:ok, AshGleam.Marshal.output!(config.return_type, result, allow_nil?: config.allow_nil?)}
  end
end
