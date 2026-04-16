defmodule AshGleam.FFITest do
  use ExUnit.Case, async: false

  setup_all do
    :ok = AshGleam.GeneratedGleamHelper.compile_and_load!()

    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
    end)

    :ok
  end

  setup do
    try do
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
    rescue
      _ -> :ok
    end

    case :ets.whereis(:ash_gleam_test_todos) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end

    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
    end)

    {:ok, bridge: AshGleam.TestDomain.Generated}
  end

  test "generated create ffi bridge creates a resource", %{bridge: _bridge} do
    create_todo_module = AshGleam.GeneratedGleamHelper.module_atom("create_todo")

    builder = create_todo_module.new("Created from ffi", false, 3)

    assert {:ok, {:todo, id, "Created from ffi", false, 3}} =
             create_todo_module.run(builder)

    assert is_binary(id)

    assert {:ok, %AshGleam.TestTodo{id: ^id, title: "Created from ffi", completed: false}} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: id})
             |> Ash.read_one()
  end

  test "generated get ffi bridge returns the requested resource", %{bridge: _bridge} do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Fetch me"})
      |> Ash.create!()

    get_todo_module = AshGleam.GeneratedGleamHelper.module_atom("get_todo")
    builder = get_todo_module.new(todo.id)

    assert {:ok, {:todo, id, "Fetch me", false, 1}} =
             get_todo_module.run(builder)

    assert id == todo.id
  end

  test "generated get ffi bridge supports first matching record with action-defined filter and sort",
       %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Zulu", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "AAA Alpha", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Beta", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    first_completed_module = AshGleam.GeneratedGleamHelper.module_atom("first_completed_todo")

    assert {:ok, {:todo, _id, "AAA Alpha", true, 1}} =
             first_completed_module
             |> apply(:new, [])
             |> first_completed_module.run()
  end

  test "generated list ffi bridge applies filter, sort, and limit", %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "! B task", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "! A task", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    list_todos_module = AshGleam.GeneratedGleamHelper.module_atom("list_todos")
    todo_item_module = AshGleam.GeneratedGleamHelper.module_atom("todo_item")

    builder =
      list_todos_module.new()
      |> list_todos_module.filter([
        todo_item_module.completed_eq(true)
      ])
      |> list_todos_module.sort([
        todo_item_module.title_asc()
      ])
      |> list_todos_module.limit({:some, 1})

    assert {:ok, [{:todo, _id, "! A task", true, 1}]} =
             list_todos_module.run(builder)
  end

  test "generated list ffi bridge filters by title across multiple todos", %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Keep me", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!()

    list_todos_module = AshGleam.GeneratedGleamHelper.module_atom("list_todos")
    todo_item_module = AshGleam.GeneratedGleamHelper.module_atom("todo_item")

    builder =
      list_todos_module.new()
      |> list_todos_module.filter([
        todo_item_module.title_eq("Filter target")
      ])
      |> list_todos_module.sort([
        todo_item_module.title_asc()
      ])
      |> list_todos_module.limit(:none)

    assert {:ok, results} =
             list_todos_module.run(builder)

    assert 2 == length(results)

    assert Enum.all?(results, fn {:todo, _id, title, _completed, _priority} ->
             title == "Filter target"
           end)

    assert Enum.sort(
             Enum.map(results, fn {:todo, _id, _title, completed, _priority} -> completed end)
           ) == [
             false,
             true
           ]
  end
end
