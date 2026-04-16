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
             %{ffi_name: :get_todo, kind: :get},
             %{ffi_name: :first_completed_todo, kind: :get}
           ] = manifest.domains[domain_key].ffi

    assert Enum.any?(manifest.gleam_actions, &(&1.action_name == :add))
    assert Enum.any?(manifest.gleam_actions, &(&1.action_name == :mark_completed))
  end

  test "codegen writes manifest, gleam modules, and elixir bridge modules" do
    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(tmp) end)

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    assert File.exists?(AshGleam.Info.manifest_path(output: tmp))

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)

    assert File.exists?(Path.join(gleam_src, "todo_item.gleam"))
    assert File.exists?(Path.join(gleam_src, "list_todos.gleam"))
    assert File.exists?(Path.join(gleam_src, "create_todo.gleam"))
    assert File.exists?(Path.join(gleam_src, "get_todo.gleam"))
    assert File.exists?(Path.join(gleam_src, "first_completed_todo.gleam"))
    assert File.read!(Path.join(gleam_src, "todo_item.gleam")) =~ "pub type Todo"

    assert File.read!(Path.join(gleam_src, "list_todos.gleam")) =~
             "pub fn run(builder: ListTodos)"

    assert File.read!(Path.join(gleam_src, "list_todos.gleam")) =~
             "import #{AshGleam.Info.gleam_module_prefix(output: tmp)}/todo_item."

    bridge_path =
      Path.join(AshGleam.Info.elixir_dir(output: tmp), "ash_gleam/test_domain/generated.ex")

    assert File.exists?(bridge_path)
    assert File.read!(bridge_path) =~ "defmodule AshGleam.TestDomain.Generated do"
  end

  test "test env codegen defaults write under test/generated/ash_gleam" do
    # on_exit(fn -> File.rm_rf!(AshGleam.Info.output_dir()) end)

    File.rm_rf!(AshGleam.Info.output_dir())

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam)

    assert File.exists?("#{AshGleam.Info.manifest_path()}")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/todo_item.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/list_todos.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/create_todo.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/get_todo.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/first_completed_todo.gleam")
    assert File.exists?("#{AshGleam.Info.elixir_dir()}/ash_gleam/test_domain/generated.ex")

    assert File.read!("#{AshGleam.Info.gleam_dir()}/list_todos.gleam") =~
             "import #{AshGleam.Info.gleam_module_prefix()}/todo_item."
  end
end
