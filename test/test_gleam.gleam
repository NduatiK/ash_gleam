import test_generated/src/first_completed_todo
import test_generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}

pub fn first_completed_from_elixir() -> Todo {
  let assert Ok(todo_item) =
    first_completed_todo.new()
    |> first_completed_todo.run()

  todo_item
}
