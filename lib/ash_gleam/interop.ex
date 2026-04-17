# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Interop do
  @moduledoc """
  Call a gleam function from Elixir
  """

  alias AshGleam.Error.ActionInterop

  @spec call!(module(), atom(), [term()], Keyword.t()) :: term()
  def call!(module, function, args, opts \\ []) do
    apply(module, function, args)
  rescue
    error ->
      ActionInterop.raise!("Gleam interop call failed",
        resource: opts[:resource],
        action: opts[:action],
        details: %{
          phase: :interop_call,
          module: module,
          function: function,
          arity: length(args),
          error: Exception.message(error),
          exception: inspect(error)
        }
      )
  catch
    kind, reason ->
      ActionInterop.raise!("Gleam interop call failed",
        resource: opts[:resource],
        action: opts[:action],
        details: %{
          phase: :interop_call,
          module: module,
          function: function,
          arity: length(args),
          kind: kind,
          reason: reason
        }
      )
  end
end
