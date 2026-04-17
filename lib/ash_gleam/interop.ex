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
      IO.inspect(error)

      raise ActionInterop,
        message: "Gleam interop call failed (#{inspect(error)})",
        resource: opts[:resource],
        action: opts[:action],
        details: %{
          phase: :call,
          module: module,
          function: function,
          arity: length(args),
          error: Exception.message(error)
        }
  catch
    kind, reason ->
      raise ActionInterop,
        message: "Gleam interop call failed",
        resource: opts[:resource],
        action: opts[:action],
        details: %{
          phase: :call,
          module: module,
          function: function,
          arity: length(args),
          kind: kind,
          reason: reason
        }
  end
end
