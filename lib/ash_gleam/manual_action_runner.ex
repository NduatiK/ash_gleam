# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.ManualActionRunner do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Unknown.UnknownError

  def run(input, opts, context) do
    config = Keyword.fetch!(opts, :config)

    args =
      Enum.map(config.arguments, fn argument ->
        value = Map.get(input.arguments, argument.name)

        AshGleam.Marshal.input!(argument.type, value,
          allow_nil?: argument.allow_nil?,
          constraints: argument.constraints
        )
      end)

    args =
      if config.pass_context? do
        ash_opts = context |> Map.get(:private, %{}) |> Map.to_list()
        [AshGleam.Context.new(ash_opts) | args]
      else
        args
      end

    result =
      AshGleam.Interop.call!(
        config.run.module,
        config.run.function,
        args,
        resource: input.resource,
        action: input.action.name
      )

    decode_result(result, config)
  end

  defp decode_result({:ok, value}, config) do
    decode_plain_result(value, config)
  end

  defp decode_result({:error, error}, _config) do
    {:error, UnknownError.exception(error: format_error(error))}
  end

  defp decode_result(value, config) do
    decode_plain_result(value, config)
  end

  defp decode_plain_result(value, config) do
    {:ok,
     AshGleam.Marshal.output!(config.return_type, value,
       allow_nil?: config.allow_nil?,
       constraints: config.constraints
     )}
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
