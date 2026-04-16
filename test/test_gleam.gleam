import test_generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}
