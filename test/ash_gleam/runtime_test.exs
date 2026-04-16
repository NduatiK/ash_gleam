defmodule AshGleam.RuntimeTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn -> Ash.DataLayer.Ets.stop(AshGleam.TestTodo) end)
    :ok
  end

  test "manual scalar gleam action runs through Ash" do
    assert {:ok, 5} = AshGleam.TestTodo.add(%{a: 2, b: 3})
  end

  test "manual resource gleam action marshals resource values in and out" do
    todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Ship tests"}, domain: AshGleam.TestDomain)
      |> Ash.create!(domain: AshGleam.TestDomain)

    assert {:ok, updated} = AshGleam.TestTodo.mark_completed(%{todo: todo})
    assert %AshGleam.TestTodo{id: id, title: "Ship tests", completed: true} = updated
    assert id == todo.id
  end

  test "resource-returning gleam actions stay pure until diffed and persisted through Ash" do
    original =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Persist me"}, domain: AshGleam.TestDomain)
      |> Ash.create!(domain: AshGleam.TestDomain)

    assert original.completed == false

    assert {:ok, proposed} = AshGleam.TestTodo.mark_completed(%{todo: original})
    assert proposed.completed == true

    assert {:ok, %AshGleam.TestTodo{completed: false}} =
             AshGleam.TestTodo
             |> Ash.Query.for_read(:get, %{id: original.id}, domain: AshGleam.TestDomain)
             |> Ash.read_one(domain: AshGleam.TestDomain)

    attrs = AshGleam.Diff.resource_changes(original, proposed)
    assert attrs == %{completed: true}

    persisted =
      original
      |> Ash.Changeset.for_update(:update, attrs, domain: AshGleam.TestDomain)
      |> Ash.update!(domain: AshGleam.TestDomain)

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
             {:todo, "todo-1", "Write docs", false}

    assert %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false} =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestTodo,
               {:todo, "todo-1", "Write docs", false}
             )
  end
end
