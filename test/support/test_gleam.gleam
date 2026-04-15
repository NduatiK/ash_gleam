pub type Todo {
  Todo(id: String, title: String, completed: Bool)
}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}
