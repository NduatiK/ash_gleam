defmodule AshGleam.CodeInterfaceTest do
  use ExUnit.Case, async: false

  setup do
    for {mod, table} <- [{AshGleam.TestTodo, :ash_gleam_test_todos}] do
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

    on_exit(fn -> Ash.DataLayer.Ets.stop(AshGleam.TestTodo) end)
    :ok
  end

  test "generated domain function persists via gleam update action" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Domain interface"})
      |> Ash.create!()

    assert todo.completed == false

    assert {:ok, updated} = AshGleam.TestDomain.mark_completed(todo)
    assert updated.completed == true
    assert updated.id == todo.id
  end

  test "bang variant raises on error and returns result on success" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Bang variant"})
      |> Ash.create!()

    updated = AshGleam.TestDomain.mark_completed!(todo)
    assert updated.completed == true
    assert updated.id == todo.id
  end

  test "domain function persists only changed fields" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Diff check", completed: false, priority: 5})
      |> Ash.create!()

    assert {:ok, updated} = AshGleam.TestDomain.mark_completed(todo)
    assert updated.completed == true
    assert updated.title == "Diff check"
    assert updated.priority == 5
  end

  test "domain function does not mutate db until called" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Pure until called"})
      |> Ash.create!()

    assert todo.completed == false

    assert {:ok, db_todo} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: todo.id})
             |> Ash.read_one()

    assert db_todo.completed == false

    AshGleam.TestDomain.mark_completed!(todo)

    assert {:ok, db_todo} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: todo.id})
             |> Ash.read_one()

    assert db_todo.completed == true
  end
end
