import gleam/list

import test_generated/src/ash_gleam/context.{type Context}
import test_generated/src/ash_gleam/math_bridge
import test_generated/src/ash_gleam/test_mark.{type TestMark, Empty}
import test_generated/src/ash_gleam/test_player.{X}
import test_generated/src/ash_gleam/test_winner.{type TestWinner, Player}
import test_generated/src/destroy_todo
import test_generated/src/first_completed_todo
import test_generated/src/gleam_admin_add
import test_generated/src/project_item.{type Project, Project}
import test_generated/src/task.{Task}
import test_generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}

pub fn add_with_context(ctx: Context, a: Int, b: Int) -> Result(Int, String) {
  gleam_admin_add.new(a, b)
  |> gleam_admin_add.set_context(ctx)
  |> gleam_admin_add.run()
}

pub fn safe_add(a: Int, b: Int) -> Result(Int, String) {
  case a < 0 || b < 0 {
    True -> Error("negative inputs are not allowed")
    False -> Ok(a + b)
  }
}

pub fn safe_mark_completed(item: Todo) -> Result(Todo, String) {
  Ok(mark_completed(item))
}

pub fn first_completed_from_elixir() -> Todo {
  let assert Ok(todo_item) =
    first_completed_todo.new()
    |> first_completed_todo.run()

  todo_item
}

pub fn delete_from_elixir(todo_item: Todo) -> Result(Bool, String) {
  destroy_todo.new(todo_item)
  |> destroy_todo.run
}

pub fn next_mark() -> TestMark {
  Empty
}

pub fn announce_winner(winner: TestWinner) -> TestWinner {
  winner
}

pub fn default_winner() -> TestWinner {
  Player(X)
}

pub fn round_trip_add(a: Int, b: Int) -> Result(Int, String) {
  math_bridge.add(a, b)
}

pub fn complete_all_tasks(project: Project) -> Project {
  let completed =
    list.map(project.items, fn(item) { Task(..item, completed: True) })
  Project(..project, items: completed)
}
