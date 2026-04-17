defmodule AshGleam.RuntimeTest do
  use ExUnit.Case, async: false

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

  test "manual gleam actions can return constrained atom enums" do
    assert {:ok, :empty} = AshGleam.TestTodo.next_mark(%{})
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

  test "output! unwraps :none and {:some, v} only when allow_nil? is true" do
    # With allow_nil?: true — unwrap
    assert AshGleam.Marshal.output!(:string, :none, allow_nil?: true) == nil
    assert AshGleam.Marshal.output!(:string, {:some, "hi"}, allow_nil?: true) == "hi"
    assert AshGleam.Marshal.output!(:integer, {:some, 42}, allow_nil?: true) == 42

    # With allow_nil?: false (default) — pass through as-is, not unwrapped
    assert AshGleam.Marshal.output!(:string, "hello", allow_nil?: false) == "hello"
    assert AshGleam.Marshal.output!(:integer, 7, allow_nil?: false) == 7
  end

  test "marshal handles scalar, nullable, array, resource, and atom enum values" do
    todo = %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false}
    atom_constraints = [one_of: [:x, :o]]

    assert AshGleam.Marshal.input!(:string, "abc", allow_nil?: false) == "abc"
    assert AshGleam.Marshal.input!(:string, nil, allow_nil?: true) == :none
    assert AshGleam.Marshal.output!(:string, :none, allow_nil?: true) == nil
    assert AshGleam.Marshal.output!({:array, :integer}, [1, 2, 3]) == [1, 2, 3]

    assert AshGleam.Marshal.input!(:atom, :x, allow_nil?: false, constraints: atom_constraints) ==
             :x

    assert AshGleam.Marshal.output!(:atom, :o, allow_nil?: false, constraints: atom_constraints) ==
             :o

    assert AshGleam.Marshal.output!(:atom, :none, allow_nil?: true, constraints: atom_constraints) ==
             nil

    assert AshGleam.Marshal.to_gleam(AshGleam.TestTodo, todo) ==
             {:todo, "todo-1", "Write docs", false, 1}

    assert %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false} =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestTodo,
               {:todo, "todo-1", "Write docs", false, 1}
             )
             
    assert %AshGleam.TestTodo{id: "todo-1", title: "Write docs", completed: false} =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestTodo,
               {:todo, "todo-1", "Write docs", false, 1}
             )
  end

  test "marshal handles reusable enum and union modules" do
    assert AshGleam.Marshal.input!(AshGleam.TestMark, :x, allow_nil?: false) == :x
    assert AshGleam.Marshal.output!(AshGleam.TestMark, :o, allow_nil?: false) == :o

    assert AshGleam.Marshal.input!(AshGleam.TestWinner, :draw, allow_nil?: false) == :draw

    assert AshGleam.Marshal.input!(AshGleam.TestWinner, {:player, :x}, allow_nil?: false) ==
             {:player, :x}

    assert AshGleam.Marshal.output!(AshGleam.TestWinner, :draw, allow_nil?: false) == :draw

    assert AshGleam.Marshal.output!(AshGleam.TestWinner, {:player, :x}, allow_nil?: false) ==
             {:player, :x}
  end

  test "gleam actions accept and return ash_sum_type values" do
    assert {:ok, :draw} = AshGleam.TestTodo.announce_winner(%{winner: :draw})
    assert {:ok, {:player, :o}} = AshGleam.TestTodo.announce_winner(%{winner: {:player, :o}})
    assert {:ok, {:player, :x}} = AshGleam.TestTodo.default_winner(%{})
  end

  test "marshal round-trips atom enum fields on resources" do
    game = %AshGleam.TestGame{
      id: "game-1",
      name: "Tic Tac Toe",
      current_player: :x,
      status: :in_progress,
      winner: :draw
    }

    assert AshGleam.Marshal.to_gleam(AshGleam.TestGame, game) ==
             {:game, "game-1", "Tic Tac Toe",
              [:none, :none, :none, :none, :none, :none, :none, :none, :none], :x,
              :in_progress, :draw}

    assert %AshGleam.TestGame{
             id: "game-1",
             name: "Tic Tac Toe",
             current_player: :x,
             status: :in_progress,
             winner: :draw
           } =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestGame,
               {:game, "game-1", "Tic Tac Toe",
                [:none, :none, :none, :none, :none, :none, :none, :none, :none], :x,
                :in_progress, :draw}
             )
  end

  test "marshal round-trips nullable atom enum fields on resources" do
    game = %AshGleam.TestGame{
      id: "game-2",
      name: "Tic Tac Toe",
      current_player: :o,
      status: :finished,
      winner: nil
    }

    assert AshGleam.Marshal.to_gleam(AshGleam.TestGame, game) ==
             {:game, "game-2", "Tic Tac Toe",
              [:none, :none, :none, :none, :none, :none, :none, :none, :none], :o,
              :finished, :none}

    assert %AshGleam.TestGame{
             id: "game-2",
             name: "Tic Tac Toe",
             current_player: :o,
             status: :finished,
             winner: nil
           } =
             AshGleam.Marshal.from_gleam(
               AshGleam.TestGame,
               {:game, "game-2", "Tic Tac Toe",
                [:none, :none, :none, :none, :none, :none, :none, :none, :none], :o,
                :finished, :none}
             )
  end

  test "marshal round-trips a project with embedded tasks" do
    task1 = %AshGleam.TestTask{id: "t-1", title: "First", completed: false, priority: 1}
    task2 = %AshGleam.TestTask{id: "t-2", title: "Second", completed: true, priority: 2}
    project = %AshGleam.TestProject{id: "p-1", name: "My Project", items: [task1, task2]}

    gleam_tuple = AshGleam.Marshal.to_gleam(AshGleam.TestProject, project)

    assert {:project, "p-1", "My Project",
            [
              {:task, "t-1", "First", false, 1},
              {:task, "t-2", "Second", true, 2}
            ]} = gleam_tuple

    restored = AshGleam.Marshal.from_gleam(AshGleam.TestProject, gleam_tuple)

    assert %AshGleam.TestProject{id: "p-1", name: "My Project"} = restored

    assert [
             %AshGleam.TestTask{id: "t-1", title: "First", completed: false},
             %AshGleam.TestTask{id: "t-2", title: "Second", completed: true}
           ] = restored.items
  end

  test "gleam action receives project with embedded tasks and returns all tasks completed" do
    task1 = %AshGleam.TestTask{id: "t-1", title: "Buy milk", completed: false, priority: 1}
    task2 = %AshGleam.TestTask{id: "t-2", title: "Write tests", completed: false, priority: 2}
    task3 = %AshGleam.TestTask{id: "t-3", title: "Ship it", completed: true, priority: 3}
    project = %AshGleam.TestProject{id: "p-1", name: "Sprint 1", items: [task1, task2, task3]}

    assert {:ok, result} = AshGleam.TestProject.complete_all_tasks(%{project: project})

    assert %AshGleam.TestProject{id: "p-1", name: "Sprint 1"} = result
    assert length(result.items) == 3
    assert Enum.all?(result.items, & &1.completed)
    assert Enum.map(result.items, & &1.title) == ["Buy milk", "Write tests", "Ship it"]
  end

  test "all task ids and order are preserved through the Gleam round-trip" do
    tasks =
      for i <- 1..3 do
        %AshGleam.TestTask{id: "t-#{i}", title: "Task #{i}", completed: false, priority: i}
      end

    project = %AshGleam.TestProject{id: "p-1", name: "Ordering test", items: tasks}

    assert {:ok, returned} = AshGleam.TestProject.complete_all_tasks(%{project: project})

    assert returned.id == project.id
    assert Enum.map(returned.items, & &1.id) == Enum.map(tasks, & &1.id)
    assert Enum.all?(returned.items, & &1.completed)
  end
end
