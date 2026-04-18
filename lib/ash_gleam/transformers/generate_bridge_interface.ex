# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Transformers.GenerateBridgeInterface do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    consume_fns = AshGleam.GleamBridge.Info.consume_functions(dsl_state)

    dsl_state =
      Enum.reduce(consume_fns, dsl_state, fn func, dsl_state ->
        define_consume_fn(dsl_state, module, func)
      end)

    {:ok, dsl_state}
  end

  defp define_consume_fn(dsl_state, module, func) do
    arg_names = Enum.map(func.arguments, & &1.name)

    Transformer.eval(
      dsl_state,
      [func_name: func.name, arg_names: arg_names, module: module],
      quote generated: true do
        def unquote(func.name)(unquote_splicing(Enum.map(arg_names, &Macro.var(&1, nil)))) do
          AshGleam.GleamBridge.ConsumeRunner.call(
            unquote(module),
            unquote(func.name),
            %{unquote_splicing(Enum.map(arg_names, fn n -> {n, Macro.var(n, nil)} end))}
          )
        end
      end
    )
  end
end
