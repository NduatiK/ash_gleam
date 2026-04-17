<!--
SPDX-FileCopyrightText: 2026 Nduati Kuria

SPDX-License-Identifier: MIT
-->

<img src="https://github.com/NduatiK/ash_gleam/blob/main/logo.png?raw=true" alt="Logo" width="300"/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_gleam.svg)](https://hex.pm/packages/ash_gleam)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_gleam)

# AshGleam

**Type-safe Gleam interop for Ash resources**

AshGleam integrates Elixir's Ash framework and Gleam into a single, cohesive system. It enables you to move data and execution across the boundary with compile-time guarantees.

You can:
- [Generate Gleam types from your Ash resources](#generate-gleam-types-from-your-ash-resources)
- [Expose Gleam functions as Ash actions](#generate-gleam-types-from-your-ash-resources)
- [Expose Ash actions in Gleam](#expose-ash-actions-to-gleam)
- [Represent Gleam custom-types in Elixir](#represent-gleam-custom-types-in-elixir)

## Installation

<details>
<summary>
  
### With Igniter (recommended)

```bash
mix igniter.install ash_gleam
```

</summary>

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

</details>
<details>
<summary>
  
### Manual setup

</summary>
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

Create a `src/` directory for your Gleam source files and add the following to your `.gitignore`:
```
# gleam build files
/build/

# intermediate generation file
/src/generated/manifest.term
```

</details>

## Generate Gleam types from your Ash resources

<details>
  <summary>
1. Add <code>AshGleam.Resource</code> to your resource and declare a <code>gleam</code> block:    
</summary>
  
```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    ...,
    extensions: [AshGleam.Resource, AshGleam.Actions]

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
</details>

<details>
  <summary>
2. Run `mix ash_gleam.codegen`
  </summary>
  
```gleam
// generated at src/generated/src/todo_item

pub type TicTacToe {
  TicTacToe(
    id: String,
    title: String,
    completed: Boolean,
  )
}
```
</details>


Only `public?: true` attributes are included in the generated Gleam type.

## Expose Gleam functions as Ash actions

<details>
  <summary>
1. Create a gleam function (make sure you have run the generator first)
  </summary>

```gleam
// Import the generated Todo type
import src/generated/src/todo_item.{type Todo, Todo}

pub fn mark_completed(item: Todo) -> Todo {
  Todo(..item, completed: True)
}
```
</details>

<details>
  <summary>
2. Add <code>AshGleam.Actions</code> to your resource and declare a <code>gleam.actions</code> block for that function
  </summary>

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
</details>

<details>
  <summary>
3. Use the exposed function
  </summary>
  
```elixir
todo = # create a todo

# mark_completed in memory
assert {:ok, updated} = MyApp.Todo.mark_completed(%{todo: todo})

# mark_completed and persist
{:ok, changeset} =
  todo
  |> AshGleam.Changeset.for_update(:mark_completed, %{}, action: :update)
  |> Ash.update!()
```
</details>

<details>
  <summary>
4. If you want a code interface that does the update for you, update your domain
  </summary>
    
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
</details>

## Expose Ash actions to Gleam

<details>
  <summary>
1. Add the resource actions you want to expose to Gleam
  </summary>
  
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
```

</details>

<details>
  <summary>
2. Create an entry in gleam.ffi for your resource actions
  </summary>

```elixir
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

</details>

3. Run `mix ash_gleam.codegen`

<details>
  <summary>
4. Use the generated gleam functions
  </summary>
  
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

</details>

## Represent Gleam custom-types in Elixir

You can define the equivalent to Gleam's custom types using `AshSumType` from [ash_sum_type](https://github.com/NduatiK/ash_sum_type).

<table>
  <thead>
    <tr>
      <th>Elixir</th>
      <th>Generated Gleam</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: var(--bgColor-muted,var(--color-canvas-subtle));">
<td>
  
```elixir
defmodule MyApp.Mark do
  use AshSumType, variants: [:x, :o]
end
```
  
</td>
<td>

```gleam
pub type Mark {
  X
  O
}
```

</td>
</tr>
<tr style="background-color: var(--bgColor-muted,var(--color-canvas-subtle));">
<td>

```elixir
defmodule MyApp.Mark do
  use AshSumType

  variant :x
  variant :o
end
```

</td>
<td>

```gleam
pub type Mark {
  X
  O
}
```

</td>
</tr>
<tr style="background-color: var(--bgColor-muted,var(--color-canvas-subtle));">
<td>
      
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

</td>
<td>

```gleam
pub type LookupOutcome {
  Found(Todo)
  Missing(String)
}
```

</td>
</tr>
  </tbody>
  
</table>


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
    ...,
    extensions: [AshGleam.Resource]

  attributes do
    ...
    # Gleam type List(Tag)
    attribute :tags, {:array, MyApp.Tag}, allow_nil?: false, default: [], public?: true

    
    # Gleam type List(Option(Tag))
    attribute :nullable_tags, {:array, MyApp.Tag}, allow_nil?: false, default: [], public?: true, nil_items?: true
  end
end
```

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
