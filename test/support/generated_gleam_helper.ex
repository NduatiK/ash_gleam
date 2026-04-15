defmodule AshGleam.GeneratedGleamHelper do
  @moduledoc false

  @package_name "ashgleam_generated"
  @generated_modules [
    AshGleam.TestDomain.Generated,
    :todo_item,
    :list_todos,
    :create_todo,
    :get_todo
  ]

  def compile_and_load! do
    File.rm_rf!(".ash_gleam")
    purge_modules()

    :ok = AshGleam.codegen(otp_app: :ash_gleam)
    File.write!(".ash_gleam/gleam.toml", gleam_toml())

    run_gleam!(["deps", "download"])
    run_gleam!(["build"])

    Code.prepend_path(find_ebin!())
    Code.compile_file(".ash_gleam/lib/ash_gleam/test_domain/generated.ex")

    :ok
  end

  def purge_modules do
    Enum.each(@generated_modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end

  defp run_gleam!(args) do
    case System.cmd("gleam", args, cd: ".ash_gleam", stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, status} ->
        raise """
        gleam #{Enum.join(args, " ")} failed with status #{status}

        #{output}
        """
    end
  end

  defp find_ebin! do
    case Path.wildcard(".ash_gleam/build/*/erlang/#{@package_name}/ebin") do
      [ebin] -> ebin
      [] -> raise "could not find generated Gleam ebin for #{@package_name}"
    end
  end

  defp gleam_toml do
    """
    name = "#{@package_name}"
    version = "0.1.0"
    target = "erlang"

    [dependencies]
    gleam_stdlib = ">= 0.62.0 and < 2.0.0"
    """
  end
end
