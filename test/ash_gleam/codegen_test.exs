defmodule AshGleam.CodegenTest do
  use ExUnit.Case, async: false

  test "manifest includes ash_gleam resources, ffi exports, and gleam actions" do
    manifest = AshGleam.manifest(otp_app: :ash_gleam)
    resource_key = inspect(AshGleam.TestTodo)
    domain_key = inspect(AshGleam.TestDomain)

    assert manifest.resources[resource_key].gleam_type == "Todo"
    assert manifest.resources[resource_key].module_name == "todo_item"

    assert [
             %{ffi_name: :list_todos, kind: :read},
             %{ffi_name: :create_todo, kind: :create},
             %{ffi_name: :get_todo, kind: :get}
           ] = manifest.domains[domain_key].ffi

    assert Enum.any?(manifest.gleam_actions, &(&1.action_name == :add))
    assert Enum.any?(manifest.gleam_actions, &(&1.action_name == :mark_completed))
  end

  test "codegen writes manifest, gleam modules, and elixir bridge modules" do
    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_#{System.unique_integer([:positive])}")
    output = Path.join(tmp, "src")
    elixir_output = Path.join(tmp, "lib")
    manifest = Path.join(tmp, "manifest.term")

    on_exit(fn -> File.rm_rf(tmp) end)

    assert :ok =
             AshGleam.codegen(
               otp_app: :ash_gleam,
               output: output,
               elixir_output: elixir_output,
               manifest: manifest
             )

    assert File.exists?(manifest)
    assert File.exists?(Path.join(output, "todo_item.gleam"))
    assert File.exists?(Path.join(output, "list_todos.gleam"))
    assert File.exists?(Path.join(output, "create_todo.gleam"))
    assert File.exists?(Path.join(output, "get_todo.gleam"))

    bridge_path = Path.join(elixir_output, "ash_gleam/test_domain/generated.ex")
    assert File.exists?(bridge_path)

    assert File.read!(Path.join(output, "todo_item.gleam")) =~ "pub type Todo"
    assert File.read!(Path.join(output, "list_todos.gleam")) =~ "pub fn run(builder: ListTodos)"
    assert File.read!(bridge_path) =~ "defmodule AshGleam.TestDomain.Generated do"
  end

  test "test env codegen defaults write under .ash_gleam" do
    # on_exit(fn -> File.rm_rf!(".ash_gleam") end)

    File.rm_rf!(".ash_gleam")

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam)

    assert File.exists?(".ash_gleam/manifest.term")
    assert File.exists?(".ash_gleam/src/todo_item.gleam")
    assert File.exists?(".ash_gleam/src/list_todos.gleam")
    assert File.exists?(".ash_gleam/src/create_todo.gleam")
    assert File.exists?(".ash_gleam/src/get_todo.gleam")
    assert File.exists?(".ash_gleam/lib/ash_gleam/test_domain/generated.ex")
  end
end
