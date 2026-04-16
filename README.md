<!--
SPDX-FileCopyrightText: 2026 Nduati Kuria

SPDX-License-Identifier: MIT
-->

<img src="https://github.com/NduatiK/ash_gleam/blob/main/logo.png?raw=true" alt="Logo" width="300"/>

![Elixir CI](https://github.com/NduatiK/ash_gleam/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_gleam.svg)](https://hex.pm/packages/ash_gleam)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_gleam)

# AshGleam

**Automatic Gleam type generation for Ash resources and actions**

Generate type-safe Gleam clients directly from your Elixir Ash resources, ensuring end-to-end type safety between your backend and frontend. Never write API types manually again.

## TODO

- Stop returning specific fields, return all public fields in the order they appear in attributes
- Test calling gleam code that calls ash code
- Ensure ash code called from gleam returns Results
- Experiment with embedded resources (the most likely usecase)
- Support destroy actions
- Handle nested types eg when nesting embedded resources
- Fix readme


## Features

<!--TODO-->

## Quick Start

**Get up and running in under 5 minutes:**

```bash
# Basic installation
# mix igniter.install ash_gleam
```

### 1. Add Resource Extension

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource]

  gleam do
    type_name "Todo"
  end
  

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :completed, :boolean, default: false
  end
end
```

### 2. Configure Domain

```elixir
defmodule MyApp.Domain do
  use Ash.Domain, extensions: [AshGleam.FFI]

  gleam_ffi do
    resource TodoApp.Todo do
      action :list_todos, :read
      action :create_todo, :create
      action :get_todo, :get
    end
  end
end
```

### 3. Generate Types & Use

```bash
mix ash.codegen --dev
```

```gleam
// import { listTodos, createTodo } from './ash_rpc';

// Fully type-safe API calls
let todos = ListTodos.new()
|> ListTodos.filter([
  CompletedEq(False)
])
|> ListTodos.sort([
  TitleAsc
])
|> ListTodos.run()


let new_todo = CreateTodo.new(
  // 
  title: "Learn AshGleam",
  priority: "high"
)
|> CreateTodo.run()
```

### 1. Add Resource Extension

```gleam
// todo_items.gleam
import ...

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}
```

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource]

  gleam do
    # ...
    actions do
      action :mark_completed, __MODULE__ do
        argument :todo_item, __MODULE__, allow_nil?: false
    
        run &:todo_items.mark_completed/1
      end
    end
  end
end
```

#### Do not need attributes

```gleam
// gleam_math.gleam
pub fn add(a: Int, b: Int) -> Int {
  a + b
}
```

```elixir
defmodule MyApp.Math do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Actions]

  gleam_actions do
    action :add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run &:gleam_math.add/2
    end
  end
end
```

**That's it!** Your Gleam frontend now has compile-time type safety for your Elixir backend.

**For complete setup instructions, see the [Installation Guide](documentation/getting-started/installation.md).**

## Documentation

### Getting Started

- **[Installation](documentation/getting-started/installation.md)** - Complete installation and setup guide
- **[Your First RPC Action](documentation/getting-started/first-rpc-action.md)** - Create your first type-safe API call
- **[Frontend Frameworks](documentation/getting-started/frontend-frameworks.md)** - React and other framework integrations

### Guides

- **[CRUD Operations](documentation/guides/crud-operations.md)** - Create, read, update, delete patterns
- **[Querying Data](documentation/guides/querying-data.md)** - Pagination, sorting, and filtering
- **[Error Handling](documentation/guides/error-handling.md)** - Comprehensive error handling strategies

### Features

<!--TODO-->

### Type Safety Benefits

- **Compile-time validation** - Gleam compiler catches API misuse before runtime
- **Autocomplete support** - Full IntelliSense for all resource fields and actions
- **Refactoring safety** - Rename fields in Elixir, get Gleam errors immediately
- **Living documentation** - Generated types serve as up-to-date API documentation

## Example Repository

<!--TODO-->

## Requirements

- Elixir 1.15 or later
- Ash 3.0 or later
- Phoenix (for RPC controller integration)
- Node.js 16+ (for Gleam)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Ensure all tests pass (`mix test`)
5. Run code formatter (`mix format`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

Please ensure:

- All tests pass
- Code is formatted with `mix format`
- Documentation is updated for new features
- Commits follow conventional commit format

## License

This project is licensed under the MIT License - see the [LICENSES/MIT.txt](https://github.com/NduatiK/ash_gleam/blob/main/LICENSES/MIT.txt) file for details.

## Support

- **Documentation**: [https://hexdocs.pm/ash_gleam](https://hexdocs.pm/ash_gleam)
- **GitHub Issues**: [https://github.com/NduatiK/ash_gleam/issues](https://github.com/NduatiK/ash_gleam/issues)


---
