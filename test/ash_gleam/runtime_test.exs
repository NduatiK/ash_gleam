defmodule AshGleam.RuntimeTest do
  use ExUnit.Case, async: false

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

    on_exit(fn -> Ash.DataLayer.Ets.stop(AshGleam.TestTodo) end)
    :ok
  end

  test "manual scalar gleam action runs through Ash" do
    assert {:ok, 5} = AshGleam.TestTodo.add(%{a: 2, b: 3})
  end

  test "gleam actions support ok and error result types for scalars" do
    assert {:ok, 5} = AshGleam.TestTodo.safe_add(%{a: 2, b: 3})

    assert {:error, error} = AshGleam.TestTodo.safe_add(%{a: -1, b: 3})

    assert %Ash.Error.Unknown{
             errors: [%Ash.Error.Unknown.UnknownError{error: "negative inputs are not allowed"}]
           } =
             error
  end

  test "manual resource gleam action marshals resource values in and out" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Ship tests"})
      |> Ash.create!()

    assert {:ok, updated} = AshGleam.TestTodo.mark_completed(%{todo: todo})
    assert %AshGleam.TestTodo{id: id, title: "Ship tests", completed: true} = updated
    assert id == todo.id
  end

  test "gleam actions support ok result types for resources" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Ship tests"})
      |> Ash.create!()

    assert {:ok, updated} = AshGleam.TestTodo.safe_mark_completed(%{todo: todo})
    assert %AshGleam.TestTodo{id: id, title: "Ship tests", completed: true} = updated
    assert id == todo.id
  end

  test "gleam actions on empty resources" do
    assert {:ok, 3} = AshGleam.TestEmptyResource.add(%{a: 1, b: 2})
  end

  test "gleam action can fetch resource data from elixir and return the generated todo record" do
    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Zulu", completed: true})
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "AAA Alpha", completed: true})
    |> Ash.create!()

    AshGleam.TestTodo
    |> Ash.Changeset.for_create(:create, %{title: "Incomplete", completed: false})
    |> Ash.create!()

    assert {:ok, fetched} = AshGleam.TestTodo.first_completed_from_elixir(%{})
    assert %AshGleam.TestTodo{title: "AAA Alpha", completed: true} = fetched
  end

  test "gleam action can delete a resource through elixir" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Delete me"})
      |> Ash.create!()

    assert {:ok, true} = AshGleam.TestTodo.delete_from_elixir(%{todo: todo})

    assert {:ok, nil} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: todo.id})
             |> Ash.read_one()
  end

  test "resource-returning gleam actions stay pure until diffed and persisted through Ash" do
    original =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Persist me"})
      |> Ash.create!()

    assert original.completed == false

    assert {:ok, proposed} = AshGleam.TestTodo.mark_completed(%{todo: original})
    assert proposed.completed == true

    assert {:ok, %AshGleam.TestTodo{completed: false}} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: original.id})
             |> Ash.read_one()

    attrs = AshGleam.Diff.resource_changes(original, proposed)
    assert attrs == %{completed: true}

    persisted =
      original
      |> Ash.Changeset.for_update(:update, attrs)
      |> Ash.update!()

    assert persisted.completed == true
    assert persisted.id == original.id
  end

  test "diff ignores unchanged and non-persistable resource fields" do
    original = %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false}
    proposed = %AshGleam.TestTodo{id: "todo-2", title: "Write docs", completed: true}

    assert AshGleam.Diff.resource_changes(original, proposed) == %{completed: true}
    assert AshGleam.resource_changes(original, proposed) == %{completed: true}
  end

  test "marshal handles scalar, nullable, array, and resource values" do
    todo = %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false}

    assert AshGleam.Marshal.input!(:string, "abc", allow_nil?: false) == "abc"
    assert AshGleam.Marshal.input!(:string, nil, allow_nil?: true) == :none
    assert AshGleam.Marshal.output!(:string, :none, allow_nil?: true) == nil
    assert AshGleam.Marshal.output!({:array, :integer}, [1, 2, 3]) == [1, 2, 3]

    assert AshGleam.Marshal.to_gleam(AshGleam.TestTodo, todo) ==
             {:todo, "todo-1", "Write docs", false, 1}

    assert %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false} =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestTodo,
               {:todo, "todo-1", "Write docs", false, 1}
             )
  end
end
