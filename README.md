<!--
SPDX-FileCopyrightText: 2026 Nduati Kuria

SPDX-License-Identifier: MIT
-->

<img src="https://github.com/NduatiK/ash_gleam/blob/main/logo.png?raw=true" alt="Logo" width="300"/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_gleam.svg)](https://hex.pm/packages/ash_gleam)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_gleam)

# AshGleam

Ash gives Elixir you a well-typed interfaced for their resources. 
AshGleam lets you interact with Gleam for statically typed business logic.

## Features

### 1. Generate Gleam code from your Ash resources

Add `AshGleam.Resource` to your resource and declare a `gleam` block:

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :todos
  end

  gleam do
    type_name "Todo"       # required — the Gleam type name
    module_name "todo_item" # optional — overrides the generated file name
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :completed, :boolean, default: false, public?: true
  end
end
```

run

```
$ mix ash_gleam.codegen
```

becomes

```gleam
pub type TicTacToe {
  TicTacToe(
    id: String,
    title: String,
    completed: Boolean,
  )
}
```

Only `public?: true` attributes are included in the generated Gleam type.

### 2. Expose Gleam functions as Ash actions

```gleam
// Import the generated Todo type
import test_generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}
```

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    ...,
    extensions: [AshGleam.Resource, AshGleam.Actions]


  gleam do
    type_name "Todo"
    module_name "todo_item"

    actions do
      action :mark_completed, __MODULE__ do
        update? true
        argument :todo, __MODULE__, allow_nil?: false

        run &:test_gleam.mark_completed/1
      end
    end
  end
end
```

```elixir
todo =
      AshGleam.TestTodo
      |> Ash.Changeset.for_create(:create, %{title: "Ship tests"})
      |> Ash.create!()

# mark_completed in memory
assert {:ok, updated} = MyApp.Todo.mark_completed(%{todo: todo})

# mark_completed and persist
{:ok, changeset} = AshGleam.Changeset.for_update(todo, :mark_completed, %{}, action: :update)
Ash.update!(changeset)
```

If you want a code interface
```elixir
defmodule MyApp.Domain do
  use Ash.Domain,
    otp_app: :my_app,
    extensions: [AshGleam.Domain]

  gleam do
    code_interface do
      resource AshGleam.TestTodo do
        define_gleam_update :mark_completed, action: :update
      end
    end
  end
end

# mark_completed and persist
{:ok, updated} = MyApp.Domain.mark_completed(todo)
```

### 3. Expose Ash actions to Gleam

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    ...,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ...

  actions do
    defaults [:read]

    create :create do
      accept [:title, :completed, :priority]
    end

    update :update do
      accept [:title, :completed, :priority]
      require_atomic? false
    end

    destroy :destroy

    read :get do
      get_by [:id]
    end

    read :first_completed do
      get? true
      filter expr(completed == true)
      prepare build(sort: [title: :asc], limit: 1)
    end
  end
end

defmodule MyApp.Domain do
  use Ash.Domain,
    otp_app: :my_app,
    extensions: [AshGleam.Domain]

  gleam do
    ffi do
      resource MyApp.Todo do
        action :list_todos, :read
        action :create_todo, :create
        action :get_todo, :get
        action :destroy_todo, :destroy
        action :first_completed, :first_completed
      end
    end
  end
end
```

```
$ mix ash_gleam.codegen
```

Use the generated gleam functions
```gleam
import myapp/generated/src/list_todos
import myapp/generated/src/todo_item.{type TodoFilter, type TodoSort}

pub fn fetch_incomplete_todo_titles(): Result(List(String), String) {
  list_todos.new()
  |> list_todos.filter([todo_item.CompletedEq(False)])
  |> list_todos.sort([todo_item.Title(Asc)])
  |> list_todos.limit(option.Some(10))
  |> list_todos.run()
  |> result.map(fn (todo_item) {
    todo_item.title
  })
}
```

## Reusable named sum types

You can define Gleam-facing sum types once on the Elixir side and reuse them in resource attributes and `gleam.actions`.

### Nullary sum types

```elixir
defmodule MyApp.Mark do
  use AshSumType

  variant :x
  variant :o
end

defmodule MyApp.Mark2 do
  use AshSumType, variants: [:x, :o]
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

### Embedded resources

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
      "_build/dev/lib/#{@app}/_gleam_artefacts",
      "_build/dev/lib/#{@app}/build"
    ],
    erlc_include_path: "_build/dev/lib/#{@app}/include",
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
