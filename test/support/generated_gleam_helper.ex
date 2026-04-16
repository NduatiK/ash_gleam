defmodule AshGleam.GeneratedGleamHelper do
  @moduledoc false

  def compile_and_load! do
    File.rm_rf!(AshGleam.Info.elixir_dir())
    purge_modules()

    :ok = AshGleam.codegen(otp_app: :ash_gleam)

    Mix.Task.reenable("compile.gleam")
    Mix.Task.run("compile.gleam")
    Mix.Task.reenable("compile.erlang")
    Mix.Task.run("compile.erlang")

    Code.prepend_path("_build/test/lib/ash_gleam/ebin")
    Code.compile_file("#{AshGleam.Info.elixir_dir()}/ash_gleam/test_domain/generated.ex")

    :ok
  end

  def purge_modules do
    Enum.each(
      [AshGleam.TestDomain.Generated, :test_gleam | generated_module_atoms()],
      fn module ->
        :code.purge(module)
        :code.delete(module)
      end
    )
  end

  defp generated_module_atoms do
    ebin_dir = "_build/test/lib/ash_gleam/ebin"
    prefix = AshGleam.Info.gleam_module_prefix() |> String.replace("/", "@") |> Kernel.<>("@")

    case File.ls(ebin_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, prefix))
        |> Enum.map(&Path.rootname(&1))
        |> Enum.map(&String.to_atom/1)

      {:error, _} ->
        []
    end
  end

  def module_atom(name) do
    AshGleam.Info.gleam_module_prefix()
    |> Kernel.<>("/#{name}")
    |> String.replace("/", "@")
    |> String.to_atom()
  end
end
