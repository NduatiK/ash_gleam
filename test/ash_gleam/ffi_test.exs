defmodule AshGleam.FFITest do
  use ExUnit.Case, async: false

  setup_all do
    :ok = AshGleam.GeneratedGleamHelper.compile_and_load!()

    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
      Ash.DataLayer.Ets.stop(AshGleam.TestProject)
    end)

    :ok
  end

  setup do
    for {mod, table} <- [
          {AshGleam.TestTodo, :ash_gleam_test_todos},
          {AshGleam.TestProject, :ash_gleam_test_projects}
        ] do
      try do
        Ash.DataLayer.Ets.stop(mod)
      rescue
        _ -> :ok
      end

      case :ets.whereis(table) do
        :undefined -> :ok
        t -> :ets.delete_all_objects(t)
      end
    end

    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
      Ash.DataLayer.Ets.stop(AshGleam.TestProject)
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
    |> Ash.Changeset.for_create(:create, %{title: "Zulu", completed: true}    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "AAA Alpha", completed: true}    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Beta", completed: false}    )
    |> Ash.create!()

    first_completed_module = AshGleam.GeneratedGleamHelper.module_atom("first_completed_todo")

    assert {:ok, {:todo, _id, "AAA Alpha", true, 1}} =
             first_completed_module
             |> apply(:new, [])
             |> first_completed_module.run()
  end

  test "generated list ffi bridge applies filter, sort, and limit", %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "! B task", completed: false}    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "! A task", completed: true}    )
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
    |> Ash.Changeset.for_create(:create, %{title: "Keep me", completed: false}    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: true}    )
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: false}    )
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

  test "generated destroy ffi bridge takes a resource and deletes it", %{bridge: _bridge} do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Destroy me"})
      |> Ash.create!()

    destroy_todo_module = AshGleam.GeneratedGleamHelper.module_atom("destroy_todo")

    builder =
      destroy_todo_module.new(AshGleam.Marshal.to_gleam(AshGleam.TestTodo, todo))

    assert {:ok, true} = destroy_todo_module.run(builder)

    assert {:ok, nil} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: todo.id})
             |> Ash.read_one()
  end

  test "create project ffi bridge stores embedded tasks and returns them as gleam tuples" do
    create_project_module = AshGleam.GeneratedGleamHelper.module_atom("create_project")

    # Gleam task tuples: {:task, id, title, completed, priority}
    gleam_tasks = [
      {:task, Ash.UUID.generate(), "Alpha", false, 1},
      {:task, Ash.UUID.generate(), "Beta", true, 2}
    ]

    builder = create_project_module.new("My Project", gleam_tasks)

    assert {:ok, {:project, id, "My Project", returned_tasks}} =
             create_project_module.run(builder)

    assert is_binary(id)
    assert length(returned_tasks) == 2

    titles = Enum.map(returned_tasks, fn {:task, _id, title, _c, _p} -> title end)
    assert "Alpha" in titles
    assert "Beta" in titles
  end

  test "get project ffi bridge returns project with all embedded tasks intact" do
    tasks = [
      %{title: "Alpha", completed: false, priority: 1},
      %{title: "Beta", completed: true, priority: 3},
      %{title: "Gamma", completed: false, priority: 2}
    ]

    project =
      AshGleam.TestProject
      |> Ash.Changeset.for_create(:create, %{name: "Fetch me", items: tasks})
      |> Ash.create!()

    get_project_module = AshGleam.GeneratedGleamHelper.module_atom("get_project")
    builder = get_project_module.new(project.id)

    assert {:ok, {:project, returned_id, "Fetch me", returned_tasks}} =
             get_project_module.run(builder)

    assert returned_id == project.id
    assert length(returned_tasks) == 3

    titles = Enum.map(returned_tasks, fn {:task, _id, title, _c, _p} -> title end)
    assert "Alpha" in titles
    assert "Beta" in titles
    assert "Gamma" in titles
  end
end
