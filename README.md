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

**Type-safe Gleam interop for Ash resources**

AshGleam bridges Elixir's [Ash framework](https://ash-hq.org) and [Gleam](https://gleam.run) in two directions:

- **Elixir → Gleam (generated bridge modules):** Generate typed Gleam modules from your Ash resources so Gleam code can call Ash actions with full compile-time type safety.
- **Gleam → Elixir (Gleam actions):** Wire compiled Gleam functions as the implementation of Ash generic actions, letting you run Gleam logic in your Elixir backend.

## How it works

AshGleam generates Gleam source files from your Ash resource definitions. Each resource becomes a typed Gleam record. Each exported Ash action becomes a Gleam module with a builder pattern and an `@external` call back into a generated Elixir bridge module.

```
mix ash_gleam.codegen
```

The generated files live in a configurable output directory (default `lib/ash_gleam/generated/src`) and are compiled alongside your regular Gleam sources.

## Supported types

| Elixir / Ash type | Gleam type |
|---|---|
| `:string`, `:uuid` | `String` |
| `:integer` | `Int` |
| `:boolean` | `Bool` |
| `:float`, `:decimal` | `Float` |
| `{:array, t}` | `List(T)` |
| Any resource with `AshGleam.Resource` | Named record type |
| `AshSumType` module | Generated Gleam union type |
| `allow_nil?: true` on any of the above | `Option(T)` |

Embedded resources (`:embedded` data layer) with the `AshGleam.Resource` extension are fully supported, including as array fields (`{:array, EmbeddedResource}`).

## Calling Ash from Gleam

### 1. Mark resources for Gleam type generation

Add `AshGleam.Resource` to your resource and declare a `gleam` block:

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource]

  gleam do
    type_name "Todo"       # required — the Gleam type name
    module_name "todo_item" # optional — overrides the generated file name
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :completed, :boolean, default: false, public?: true
  end

  # ...
end
```

Only `public?: true` attributes are included in the generated Gleam type.

### 2. Export actions through a domain

Add `AshGleam.Domain` to your domain and list the actions you want to expose inside the `gleam` DSL:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain,
    otp_app: :my_app,
    extensions: [AshGleam.Domain]

  resources do
    resource MyApp.Todo
  end

  gleam do
    ffi do
      resource MyApp.Todo do
        action :list_todos, :read
        action :create_todo, :create
        action :get_todo, :get
        action :destroy_todo, :destroy
      end
    end
  end
end
```

### 3. Run codegen

```bash
mix ash_gleam.codegen
```

### 4. Use from Gleam

Each exported action becomes its own Gleam module. The first name in `action :list_todos, :read` becomes the generated module name.

**Listing:**
```gleam
import myapp/generated/src/list_todos
import myapp/generated/src/todo_item.{type TodoFilter, type TodoSort}

pub fn fetch_incomplete(): Result(List(Todo), String) {
  list_todos.new()
  |> list_todos.filter([todo_item.completed_eq(False)])
  |> list_todos.sort([todo_item.title_asc()])
  |> list_todos.limit(option.Some(10))
  |> list_todos.run()
}
```

**Creating:**
```gleam
import myapp/generated/src/create_todo

pub fn add_todo(title: String): Result(Todo, String) {
  create_todo.new(title, False, 1)
  |> create_todo.run()
}
```

**Reading a single record:**
```gleam
import myapp/generated/src/get_todo

pub fn find_todo(id: String): Result(Todo, String) {
  get_todo.new(id)
  |> get_todo.run()
}
```

**Deleting:**
```gleam
import myapp/generated/src/destroy_todo
import myapp/generated/src/todo_item.{type Todo}

pub fn remove_todo(todo_item: Todo): Result(Bool, String) {
  destroy_todo.DestroyTodo(todo_item)
  |> destroy_todo.run()
}
```

## Gleam actions — calling Gleam from Elixir

The `AshGleam.Actions` extension lets you implement Ash generic actions in Gleam. The Gleam function is compiled to BEAM and called directly — no HTTP, no serialization overhead.

### 1. Write a Gleam function

```gleam
// todo_logic.gleam
import myapp/generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}

pub fn safe_add(a: Int, b: Int) -> Result(Int, String) {
  case a < 0 || b < 0 {
    True -> Error("negative numbers not allowed")
    False -> Ok(a + b)
  }
}
```

### 2. Wire it to an Ash action

Add `AshGleam.Actions` to your resource and declare the action with a MFA reference:

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  # ...

  gleam do
    actions do
      # Takes a Todo, returns a Todo
      action :mark_completed, __MODULE__ do
        argument :todo, __MODULE__, allow_nil?: false
        update? true
        run &:todo_logic.mark_completed/1
      end
  
      # Takes two integers, returns Result(Int, String)
      action :safe_add, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false
        run &:todo_logic.safe_add/2
      end
  
      # Returns a reusable sum type
      action :next_mark, MyApp.Mark do
        run &:todo_logic.next_mark/0
      end
    end
  end
end
```

## Reusable named sum types

You can define Gleam-facing sum types once on the Elixir side and reuse them in resource attributes and `gleam.actions`.

### Nullary sum types

```elixir
defmodule MyApp.Mark do
  use AshSumType

  variant :x
  variant :o
  variant :empty
end

defmodule MyApp.Board do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  gleam do
    type_name "Board"
    
    actions do
      action :next_mark, MyApp.Mark do
        run &:board_logic.next_mark/0
      end
    end
  end

  attributes do
    attribute :next_mark, MyApp.Mark, public?: true
  end
end
```

AshGleam will generate one shared Gleam type module for `MyApp.Mark` and reuse it everywhere instead of generating one type per field or action:

```gleam
pub type Mark {
  X
  O
  Empty
}
```

### Sum types with payloads

Use `AshSumType` variants with carried fields when you want constructors that hold values:

```elixir
defmodule MyApp.LookupOutcome do
  use AshSumType

  variant :found do
    field :value, MyApp.Todo, allow_nil?: false
  end

  variant :missing do
    field :error, :string, allow_nil?: false
  end
end
```

That maps to a generated Gleam union like:

```gleam
pub type LookupOutcome {
  Found(Todo)
  Missing(String)
}
```

`AshSumType` values stay regular sum-type data across the boundary. Nullary variants map to atoms on the Elixir side, and payload variants map to tagged tuples in declared field order. Action `Result(T, String)` behavior is unchanged: if a Gleam action returns `Result`, AshGleam still treats `{:ok, value}` / `{:error, error}` as the action success/error channel.

### 3. Call it through Ash

Scalar-returning and non-update Gleam actions can still be called directly through the generated resource functions:

```elixir
todo = MyApp.Todo |> Ash.Changeset.for_create(:create, %{title: "Ship it"}) |> Ash.create!()

{:ok, 5} = MyApp.Todo.safe_add(%{a: 2, b: 3})
{:error, _} = MyApp.Todo.safe_add(%{a: -1, b: 3})
```

Gleam functions that return `Result(T, String)` map to `{:ok, value}` / `{:error, %Ash.Error.Unknown{}}`. Functions that return a bare value are always wrapped in `{:ok, value}`.

For Gleam actions marked `update? true`, prefer `AshGleam.Changeset.for_update/4` when you want to inspect or modify the changeset before persisting:

```elixir
todo =
  MyApp.Todo
  |> Ash.Changeset.for_create(:create, %{title: "Ship it"})
  |> Ash.create!()

{:ok, changeset} =
  AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)

persisted = Ash.update!(changeset)
persisted.completed #=> true
```

If you want a code interface that persists the update for you, configure it on the domain:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain,
    otp_app: :my_app,
    extensions: [AshGleam.Domain]

  resources do
    resource MyApp.Todo
  end

  gleam do
    code_interface do
      resource MyApp.Todo do
        define_gleam_update :mark_completed, action: :update
      end
    end
  end
end
```

That generates domain functions like `mark_completed/1-3` and `mark_completed!/1-3`:

```elixir
todo =
  MyApp.Todo
  |> Ash.Changeset.for_create(:create, %{title: "Ship it"})
  |> Ash.create!()

{:ok, updated} = MyApp.Domain.mark_completed(todo)
updated.completed #=> true
```

`AshGleam.Diff.resource_changes/2` is still available when you need the raw diff, but it is no longer the recommended primary workflow for update-style Gleam actions.

## Embedded resources

Resources with the `:embedded` data layer work as field types in other resources. The embedded resource gets its own Gleam type and is imported automatically in the parent resource's generated file.

```elixir
defmodule MyApp.Tag do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: :embedded,
    extensions: [AshGleam.Resource]

  gleam do
    type_name "Tag"
  end

  attributes do
    attribute :label, :string, allow_nil?: false, public?: true
    attribute :color, :string, allow_nil?: false, public?: true
  end
end

defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Resource]

  gleam do
    type_name "Todo"
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :tags, {:array, MyApp.Tag}, allow_nil?: false, default: [], public?: true
  end
end
```

The generated `todo_item.gleam` will import `tag.gleam` and use `List(Tag)` as the field type. All marshalling through Gleam actions and generated bridge calls handles the nested types transparently.

## Gleam functions calling back into Elixir

Gleam actions can use the generated bridge modules to call Ash actions, enabling patterns where Gleam orchestrates Ash reads or writes:

```gleam
import myapp/generated/src/first_completed_todo

pub fn get_first_completed() -> Todo {
    first_completed_todo.new()
    |> first_completed_todo.run()
}
```

## Configuration

In `config/config.exs` (or environment-specific config):

```elixir
config :ash_gleam,
  output: "lib/my_app/generated"  # default: "lib/ash_gleam/generated"
```

The generated output directory must be under a `src/` parent so that Gleam's module path resolution works. The module prefix used in `import` statements is derived from the path automatically.

## Installation

### With Igniter (recommended)

```bash
mix igniter.install ash_gleam
# If testing locally:
mix igniter.install ash_gleam@path:..
```

This automatically configures your `mix.exs` with all the settings required by
[MixGleam](https://github.com/gleam-lang/mix_gleam): compilers, `erlc_paths`,
`erlc_include_path`, `prune_code_paths`, the `deps.get` alias, and the
`gleam_stdlib` / `gleeunit` dependencies. It also creates the `src/` directory
and adds `build/` to your `.gitignore`.

You will still need to install the Gleam compiler and the MixGleam archive:

```bash
# Install the Gleam compiler — see https://gleam.run/getting-started/installing-gleam.html

# Install the MixGleam Mix archive
mix archive.install hex mix_gleam
```

### Manual setup

Add `ash_gleam` to your dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:ash_gleam, "~> 0.1"},
    {:gleam_stdlib, "~> 0.34 or ~> 1.0"},
    {:gleeunit, "~> 1.0", only: [:dev, :test], runtime: false}
  ]
end
```

Then follow the [MixGleam README](https://github.com/gleam-lang/mix_gleam) to
configure your project:

```elixir
# mix.exs
@app :my_app

def project do
  [
    app: @app,
    # ...
    archives: [mix_gleam: "~> 0.6"],
    compilers: [:gleam | Mix.compilers()],
    aliases: [
      "deps.get": ["deps.get", "gleam.deps.get"]
    ],
    erlc_paths: [
      "_build/dev/erlang/#{@app}/_gleam_artefacts",
      "_build/dev/erlang/#{@app}/build"
    ],
    erlc_include_path: "_build/dev/erlang/#{@app}/include",
    prune_code_paths: false
  ]
end
```

Create a `src/` directory for your Gleam source files and add `build/` to your
`.gitignore`.

## Requirements

- Elixir 1.15+
- Ash 3.0+
- Gleam (with `mix_gleam` configured)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for any new behaviour
4. Run `mix test` and `mix format`
5. Open a pull request

## License

MIT — see [LICENSES/MIT.txt](https://github.com/NduatiK/ash_gleam/blob/main/LICENSES/MIT.txt).

## Links

- **Hex**: [https://hex.pm/packages/ash_gleam](https://hex.pm/packages/ash_gleam)
- **Docs**: [https://hexdocs.pm/ash_gleam](https://hexdocs.pm/ash_gleam)
- **Issues**: [https://github.com/NduatiK/ash_gleam/issues](https://github.com/NduatiK/ash_gleam/issues)
