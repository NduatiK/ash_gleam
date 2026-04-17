defmodule AshGleam.PolicyTest do
  use ExUnit.Case, async: false

  @table :ash_gleam_test_policy_todos

  setup do
    :test_gleam_policy.reset()

    try do
      Ash.DataLayer.Ets.stop(AshGleam.TestPolicyTodo)
    rescue
      _ -> :ok
    end

    case :ets.whereis(@table) do
      :undefined -> :ok
      t -> :ets.delete_all_objects(t)
    end

    on_exit(fn -> Ash.DataLayer.Ets.stop(AshGleam.TestPolicyTodo) end)
    :ok
  end

  defp create_todo!(title) do
    AshGleam.TestPolicyTodo
    |> Ash.Changeset.for_create(:create, %{title: title}, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  defp admin_actor, do: %{role: :admin}
  defp user_actor, do: %{role: :user}

  # --- Non-update Gleam action policy tests ---

  test "authorized actor can invoke a non-update Gleam action" do
    assert {:ok, 5} = AshGleam.TestPolicyTodo.add(%{a: 2, b: 3}, actor: admin_actor())
  end

  test "unauthorized actor is forbidden from a non-update Gleam action" do
    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyTodo.add(%{a: 2, b: 3}, actor: user_actor())
  end

  test "Gleam function is not called when non-update action is forbidden" do
    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyTodo.add(%{a: 2, b: 3}, actor: user_actor())

    assert :test_gleam_policy.call_count(:add) == 0
  end

  # --- Direct Gleam action policy tests ---

  test "authorized actor can invoke a Gleam-backed action" do
    todo = create_todo!("Policy test")

    assert {:ok, updated} =
             AshGleam.TestPolicyTodo.mark_completed(%{todo: todo}, actor: admin_actor())

    assert updated.completed == true
  end

  test "unauthorized actor is forbidden from invoking a Gleam-backed action" do
    todo = create_todo!("Policy test")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyTodo.mark_completed(%{todo: todo}, actor: user_actor())
  end

  test "Gleam function is not executed when authorization fails" do
    todo = create_todo!("No call")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyTodo.mark_completed(%{todo: todo}, actor: user_actor())

    assert :test_gleam_policy.call_count(:mark_completed) == 0
  end

  test "Gleam function is executed when authorization passes" do
    todo = create_todo!("Call me")

    assert {:ok, _} =
             AshGleam.TestPolicyTodo.mark_completed(%{todo: todo}, actor: admin_actor())

    assert :test_gleam_policy.call_count(:mark_completed) == 1
  end

  # --- AshGleam.Changeset.for_update policy tests ---

  test "for_update: authorized actor can invoke the Gleam action step" do
    todo = create_todo!("Changeset policy test")

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{},
               action: :update,
               actor: admin_actor()
             )

    assert %Ash.Changeset{valid?: true} = changeset
  end

  test "for_update: unauthorized actor is forbidden on the Gleam action step" do
    todo = create_todo!("Changeset forbidden")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{},
               action: :update,
               actor: user_actor()
             )
  end

  test "for_update: Gleam function not called when Gleam action step is forbidden" do
    todo = create_todo!("No gleam call")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{},
               action: :update,
               actor: user_actor()
             )

    assert :test_gleam_policy.call_count(:mark_completed) == 0
  end

  test "for_update: actor flows to the update changeset so persistence policy also applies" do
    todo = create_todo!("Persist policy")

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{},
               action: :update,
               actor: admin_actor()
             )

    assert {:ok, updated} = Ash.update(changeset, actor: admin_actor())
    assert updated.completed == true
  end

  test "for_update: persistence is forbidden when actor is not authorized for the update action" do
    todo = create_todo!("Persist forbidden")

    assert {:ok, changeset} =
             AshGleam.Changeset.for_update(todo, :mark_completed, %{},
               action: :update,
               actor: admin_actor()
             )

    assert {:error, %Ash.Error.Forbidden{}} = Ash.update(changeset, actor: user_actor())
    assert todo.completed == false
  end

  # --- Domain code interface policy tests ---

  test "domain interface: authorized actor can invoke and persist" do
    todo = create_todo!("Domain policy")

    assert {:ok, updated} =
             AshGleam.TestPolicyDomain.mark_completed(todo, %{}, actor: admin_actor())

    assert updated.completed == true
  end

  test "domain interface: unauthorized actor is forbidden on the Gleam action step" do
    todo = create_todo!("Domain forbidden")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyDomain.mark_completed(todo, %{}, actor: user_actor())
  end

  test "domain interface: Gleam function not called when forbidden" do
    todo = create_todo!("Domain no call")

    assert {:error, %Ash.Error.Forbidden{}} =
             AshGleam.TestPolicyDomain.mark_completed(todo, %{}, actor: user_actor())

    assert :test_gleam_policy.call_count(:mark_completed) == 0
  end

  test "domain interface bang variant raises on authorization failure" do
    todo = create_todo!("Bang forbidden")

    assert_raise Ash.Error.Forbidden, fn ->
      AshGleam.TestPolicyDomain.mark_completed!(todo, %{}, actor: user_actor())
    end
  end
end
