defmodule AshGleam.FFITest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(AshGleam.TestTodo)
      AshGleam.GeneratedGleamHelper.purge_modules()
    end)

    :ok = AshGleam.GeneratedGleamHelper.compile_and_load!()
    {:ok, bridge: AshGleam.TestDomain.Generated}
  end

  test "generated create ffi bridge creates a resource", %{bridge: _bridge} do
    builder =
      apply(AshGleam.GeneratedGleamHelper.module_atom("create_todo"), :new, [
        "Created from ffi",
        false
      ])

    assert {:ok, {:todo, id, "Created from ffi", false}} =
             apply(AshGleam.GeneratedGleamHelper.module_atom("create_todo"), :run, [builder])

    assert is_binary(id)

    assert {:ok, %AshGleam.TestTodo{id: ^id, title: "Created from ffi", completed: false}} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: id}, domain: AshGleam.TestDomain)
             |> Ash.read_one(domain: AshGleam.TestDomain)
  end

  test "generated get ffi bridge returns the requested resource", %{bridge: _bridge} do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Fetch me"}, domain: AshGleam.TestDomain)
      |> Ash.create!(domain: AshGleam.TestDomain)

    get_todo_module = AshGleam.GeneratedGleamHelper.module_atom("get_todo")
    todo_item_module = AshGleam.GeneratedGleamHelper.module_atom("todo_item")

    builder =
      todo.id
      |> then(&apply(get_todo_module, :new, [&1]))
      |> then(
        &apply(get_todo_module, :fields, [
          &1,
          [
            apply(todo_item_module, :title_field, []),
            apply(todo_item_module, :completed_field, [])
          ]
        ])
      )

    assert {:ok, {:todo, id, "Fetch me", false}} =
             apply(get_todo_module, :run, [builder])

    assert id == todo.id
  end

  test "generated list ffi bridge applies fields, filter, sort, and limit", %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "B task", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!(domain: AshGleam.TestDomain)

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "A task", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!(domain: AshGleam.TestDomain)

 list_todos_module=   AshGleam.GeneratedGleamHelper.module_atom("list_todos")
 todo_item_module=   AshGleam.GeneratedGleamHelper.module_atom("todo_item")

    builder =
      list_todos_module.new()
      |> then(
        &apply(list_todos_module, :fields, [
          &1,
          [
            apply(todo_item_module, :title_field, []),
            apply(todo_item_module, :completed_field, [])
          ]
        ])
      )
      |> then(
        &apply(list_todos_module, :filter, [
          &1,
          [apply(todo_item_module, :completed_eq, [true])]
        ])
      )
      |> then(
        &apply(list_todos_module, :sort, [
          &1,
          [apply(todo_item_module, :title_asc, [])]
        ])
      )
      |> then(&apply(list_todos_module, :limit, [&1, {:some, 1}]))

    assert {:ok, [{:todo, _id, "A task", true}]} =
             apply(list_todos_module, :run, [builder])
  end

  test "generated list ffi bridge filters by title across multiple todos", %{bridge: _bridge} do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Keep me", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!(domain: AshGleam.TestDomain)

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: true},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!(domain: AshGleam.TestDomain)

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Filter target", completed: false},
      domain: AshGleam.TestDomain
    )
    |> Ash.create!(domain: AshGleam.TestDomain)

    list_todos_module=AshGleam.GeneratedGleamHelper.module_atom("list_todos")
todo_item_module=AshGleam.GeneratedGleamHelper.module_atom("todo_item")
    builder =
      apply(list_todos_module, :new, [])
      |> then(
        &apply(list_todos_module, :fields, [
          &1,
          [
            apply(todo_item_module, :title_field, []),
            apply(todo_item_module, :completed_field, [])
          ]
        ])
      )
      |> then(
        &apply(list_todos_module, :filter, [
          &1,
          [
            apply(todo_item_module, :title_eq, [
              "Filter target"
            ])
          ]
        ])
      )
      |> then(
        &apply(list_todos_module, :sort, [
          &1,
          [apply(todo_item_module, :title_asc, [])]
        ])
      )
      |> then(&apply(list_todos_module, :limit, [&1, :none]))

    assert {:ok, results} =
             apply(list_todos_module, :run, [builder])

    assert 2 == length(results)
    assert Enum.all?(results, fn {:todo, _id, title, _completed} -> title == "Filter target" end)

    assert Enum.sort(Enum.map(results, fn {:todo, _id, _title, completed} -> completed end)) == [
             false,
             true
           ]
  end
end
