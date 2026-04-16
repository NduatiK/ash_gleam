defmodule AshGleam.GeneratedGleamHelper do
  @moduledoc false

  def compile_and_load! do
    File.rm_rf!(AshGleam.Info.elixir_dir())
    purge_modules()

    :ok = AshGleam.codegen(otp_app: :ash_gleam)
    Mix.Task.reenable("compile.gleam")
    Mix.Task.run("compile.gleam")

    Code.prepend_path("_build/test/lib/ash_gleam/ebin")
    Code.compile_file("#{AshGleam.Info.elixir_dir()}/ash_gleam/test_domain/generated.ex")

    :ok
  end

  def purge_modules do
    Enum.each(
      [
        AshGleam.TestDomain.Generated
        | Enum.map(~w(todo_item list_todos create_todo get_todo), &module_atom/1)
      ],
      fn module ->
        :code.purge(module)
        :code.delete(module)
      end
    )
  end

  def module_atom(name) do
    AshGleam.Info.gleam_module_prefix()
    |> Kernel.<>("/#{name}")
    |> String.replace("/", "@")
    |> String.to_atom()
  end
end
