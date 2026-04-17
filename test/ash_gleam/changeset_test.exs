defmodule AshGleam.ChangesetTest do
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

  test "for_update builds a valid changeset from an update-style gleam action" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Ship it"})
      |> Ash.create!()

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)

    assert %Ash.Changeset{valid?: true} = changeset
    assert Ash.Changeset.get_attribute(changeset, :completed) == true
  end

  test "for_update changeset can be persisted with Ash.update!" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Persist me"})
      |> Ash.create!()

    assert todo.completed == false

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)

    persisted = Ash.update!(changeset)

    assert persisted.completed == true
    assert persisted.id == todo.id
  end

  test "for_update diff includes only changed attributes" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Diff me", completed: false})
      |> Ash.create!()

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)

    assert changeset.attributes == %{completed: true}
  end

  test "for_update requires the action: opt" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Missing action"})
      |> Ash.create!()

    assert_raise KeyError, fn ->
      AshGleam.Changeset.for_update(todo, :mark_completed, %{}, [])
    end
  end

  test "for_update raises when gleam action does not exist" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Bad action"})
      |> Ash.create!()

    assert_raise ArgumentError, ~r/does not exist/, fn ->
      AshGleam.Changeset.for_update(todo, :nonexistent, %{}, action: :update)
    end
  end

  test "for_update raises when gleam action is not marked update? true" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Non-update action"})
      |> Ash.create!()

    assert_raise ArgumentError, ~r/not marked `update\? true`/, fn ->
      AshGleam.Changeset.for_update(todo, :safe_mark_completed, %{}, action: :update)
    end
  end

  test "caller can inspect the changeset before persisting" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Inspect me"})
      |> Ash.create!()

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)

    assert %Ash.Changeset{} = changeset
    assert changeset.data.id == todo.id
  end
end
