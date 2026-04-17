defmodule :test_gleam_policy do
  @moduledoc false

  @counter_table :ash_gleam_policy_call_counter

  def mark_completed(todo) do
    increment_counter(:mark_completed)
    :test_gleam.mark_completed(todo)
  end

  def add(x, y) do
    increment_counter(:add)
    :test_gleam.add(x, y)
  end

  def increment_counter(action) do
    ensure_table()
    :ets.update_counter(@counter_table, action, {2, 1}, {action, 0})
  end

  def call_count(action) do
    ensure_table()

    case :ets.lookup(@counter_table, action) do
      [{^action, count}] -> count
      [] -> 0
    end
  end

  def reset do
    ensure_table()
    :ets.delete_all_objects(@counter_table)
  end

  defp ensure_table do
    if :ets.whereis(@counter_table) == :undefined do
      :ets.new(@counter_table, [:named_table, :public, :set])
    end
  end
end
