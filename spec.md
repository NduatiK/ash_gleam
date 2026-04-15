# ash_gleam Final Specification

## 1. Purpose

`ash_gleam` is an Ash extension library for two-way interoperability between Ash resources/domains and Gleam code on the Erlang/BEAM target.

It provides three capabilities:

1. **Gleam type generation from Ash resources**
   - Generate Gleam resource types and related helper types from Ash resource definitions.

2. **Typed Gleam FFI wrappers from Ash domains**
   - Generate Gleam modules that call Ash actions directly via BEAM interop (no transport layer).

3. **Ash actions implemented in Gleam**
   - Allow Ash resource actions to call compiled Gleam functions, with automatic conversion of supported Ash values into Gleam-compatible values and conversion of returned Gleam values back into Elixir/Ash values.

The library is BEAM-first and only supports projects compiling Gleam to the Erlang target.

---

## 2. Goals

### 2.1 Primary goals

- Make Ash resources available as strongly-typed Gleam data structures.
- Make selected Ash actions callable from Gleam through generated, compile-time-safe FFI wrappers.
- Make selected Ash actions executable by delegating action logic to Gleam functions.
- Preserve schema-driven correctness by deriving type and action contracts from Ash DSL.
- Fail early when unsupported types or invalid interop boundaries are declared.

### 2.2 Non-goals for v1

- Full support for all Ash types.
- Automatic relationship graph marshalling.
- JavaScript-target Gleam support.
- Arbitrary custom Gleam type interop.
- Persistence-aware update semantics for Gleam-backed resource transformations.
- Transparent support for embedded resources, unions, or calculations.

---

## 3. High-level architecture

`ash_gleam` consists of three extensions:

- `AshGleam.Resource`
- `AshGleam.FFI`
- `AshGleam.Actions`

### 3.1 `AshGleam.Resource`

Attached to an `Ash.Resource`.

Responsibilities:
- define Gleam metadata for the resource
- validate supported field types
- contribute resource metadata to the codegen manifest
- enable resource marshalling for Gleam-backed actions

### 3.2 `AshGleam.FFI`

Attached to an `Ash.Domain`.

Responsibilities:
- declare which Ash actions should be exported to Gleam via BEAM interop
- define per-action wrapper generation settings
- contribute FFI metadata to the codegen manifest

### 3.3 `AshGleam.Actions`

Attached to an `Ash.Resource`.

Responsibilities:
- declare Ash actions whose implementation lives in Gleam
- validate input and output interop types
- generate or register Ash manual action runners
- connect Ash action execution to compiled Gleam functions

### 3.4 Manifest-driven codegen

The library uses a manifest as the boundary between:
- compile-time DSL collection/validation
- file generation into Gleam source

This separates DSL processing from filesystem side effects and keeps codegen deterministic.

---

## 4. Supported platform/runtime assumptions

### 4.1 Required environment

- Elixir project using Ash
- Gleam integrated into the same Mix project using `mix_gleam`
- Gleam target set to Erlang/BEAM

### 4.2 Explicitly unsupported

- Gleam JavaScript target for action execution
- remote/non-BEAM Gleam execution
- calling uncompiled `.gleam` source at runtime

### 4.3 Runtime model

Gleam-backed Ash actions do **not** execute source files directly.

The `run &:module_name.function_name/arity` declaration directly references the compiled BEAM module/function target. Runtime execution occurs by calling the compiled Gleam module through the BEAM.

---

## 5. Public DSL

## 5.1 Resource extension

Example:

```elixir
defmodule TodoApp.Todo do
  use Ash.Resource,
    domain: TodoApp.Domain,
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

### `gleam` section

Supported options:

- `type_name "Todo"` — required
- `module_name "todo"` — optional override for generated Gleam module naming

Semantics:
- `type_name` defines the exported Gleam type constructor/type identity.
- resource fields become generated Gleam fields if their types are supported.

---

## 5.2 Domain FFI extension

Example:

```elixir
defmodule TodoApp.TodosDomain do
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

### `gleam_ffi` section

#### `resource ResourceModule do ... end`

Declares FFI exports for a specific Ash resource.

#### `action :ffi_name, :ash_action`

Declares a generated Gleam wrapper for the given Ash action.

Supported action kinds in v1:
- `:read`
- `:create`
- `:get`

Semantics:
- the first atom is the generated/public FFI identity
- the second atom refers to the underlying Ash action to invoke

---

## 5.3 Gleam-backed action extension

Example:

```elixir
defmodule MyApp.Math do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshGleam.Actions]

  gleam_actions do
    action :add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run &:math.add/2
    end
  end
end
```

Resource-returning example:

```elixir
defmodule TodoApp.Todo do
  use Ash.Resource,
    domain: TodoApp.TodosDomain,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  gleam do
    type_name "Todo"
  end

  gleam_actions do
    action :mark_completed, __MODULE__ do
      argument :todo, __MODULE__, allow_nil?: false
  
      run &:todo.mark_completed/1
    end
  end
end
```

### `gleam_actions` section

#### `action :name, return_type do ... end`

Defines a Gleam-backed Ash action.

- `:name` is the Ash action name.
- `return_type` is either a supported Ash scalar type or an Ash resource module using `AshGleam.Resource`.

#### `argument :name, type, opts`

Defines a supported action argument.

Options:
- `allow_nil?: boolean`

#### `run &:module_name.function_name/arity`

Defines the target Gleam function using a function reference.

The reference must be of the form:

    &:module_name.function_name/arity

Semantics:
- `module_name` refers to the compiled Gleam module (as exposed on the BEAM)
- `function_name` is the exported Gleam function
- `arity` must match the declared argument count

This form provides a direct, stable runtime call target.

### Action semantics

All `gleam_actions` actions are implemented as Ash manual/generic actions in v1, regardless of whether they return scalars or resource-shaped values.

Returned resource-shaped values are treated as action results, not persisted updates, unless a future version adds explicit persistence integration.

---

## 6. Supported type system

## 6.1 Supported scalar mappings in v1

| Ash type | Gleam type | Notes |
|---|---|---|
| `:string` | `String` | supported |
| `:integer` | `Int` | supported |
| `:boolean` | `Bool` | supported |
| `:float` | `Float` | supported |
| `:decimal` | `Float` | optional/limited; precision caveat |
| `:uuid` | `String` | supported |
| `{:array, t}` | `List(t)` | only if `t` is supported |

### v1 exclusions

- `:map`
- `:term`
- `:union`
- arbitrary embedded types
- arbitrary atoms as first-class values
- tuples
- keyword lists
- non-resource structs

---

## 6.2 Nullable mapping

- `allow_nil?: false` → bare Gleam value
- `allow_nil?: true` → `Option(value_type)`

---

## 6.3 Resource mappings

An Ash resource may be used as an argument or return type in `gleam_actions` only if:

1. it uses `AshGleam.Resource`
2. its fields are fully supported by the `ash_gleam` type mapper
3. its generated Gleam type is available to the target Gleam module

---

## 7. Code generation outputs

## 7.1 Generated Gleam resource module

For a resource like `TodoApp.Todo`, `ash_gleam` generates a Gleam module containing:

- the resource type
- field selectors/enums
- sort variants
- filter variants

Illustrative shape:

```gleam
pub type Todo {
  Todo(
    id: String,
    title: String,
    completed: Bool,
  )
}

pub type TodoField {
  Id
  Title
  Completed
}

pub type TodoSort {
  IdAsc
  IdDesc
  TitleAsc
  TitleDesc
  CompletedAsc
  CompletedDesc
}

pub type TodoFilter {
  IdEq(String)
  TitleEq(String)
  CompletedEq(Bool)
}
```

---

## 7.2 Generated Gleam RPC modules

For each declared `ffi_action`, `ash_gleam` generates a builder-style module.

Illustrative shape:

```gleam
pub type ListTodos {
  ListTodos(
    fields: List(String),
    filter: List(TodoFilter),
    sort: List(TodoSort),
    limit: Option(Int),
  )
}

pub fn new() -> ListTodos {
  ListTodos([], [], [], None)
}

pub fn filter(builder: ListTodos, filters: List(TodoFilter)) -> ListTodos {
  let ListTodos(fields, _, sort, limit) = builder
  ListTodos(fields, filters, sort, limit)
}

pub fn sort(builder: ListTodos, sorts: List(TodoSort)) -> ListTodos {
  let ListTodos(fields, filter, _, limit) = builder
  ListTodos(fields, filter, sorts, limit)
}


@external(erlang, "TodoApp.TodosDomain.GleamActions.ListTodos", "add")
pub fn run(builder: ListTodos) -> Result(List(Todo), AshError)
```

---

## 7.3 Generated Elixir action runners

For each `gleam_actions` action, `ash_gleam` generates or registers an Elixir runner module implementing the Ash manual action contract.
In the example above, this module is named `<ProjectName>.<DomainName>.Generated` eg `TodoApp.TodosDomain.Generated`

---

## 7.4 Generated Elixir action runners

For each `gleam_actions` action, `ash_gleam` generates or registers an Elixir runner module implementing the Ash manual action contract.

Responsibilities:
- read and validate Ash input arguments
- marshal them to Gleam-compatible values
- call the compiled Gleam BEAM function
- convert the returned value into an Ash-valid Elixir result
- wrap interop failures in structured action errors

---

## 8. Manifest specification

The manifest is the intermediate representation used by codegen.

Illustrative structure:

```elixir
%{
  resources: %{
    "TodoApp.Todo" => %{
      gleam_type: "Todo",
      module_name: "todo",
      fields: [
        %{name: :id, type: :uuid, allow_nil?: false},
        %{name: :title, type: :string, allow_nil?: false},
        %{name: :completed, type: :boolean, allow_nil?: false}
      ]
    }
  },
  domains: %{
    "TodoApp.TodosDomain" => %{
      ffi: [
        %{
          resource: "TodoApp.Todo",
          ffi_name: :list_todos,
          action: :read,
          kind: :read
        }
      ]
    }
  },
  gleam_actions: [
    %{
      resource: "TodoApp.Todo",
      action_name: :mark_completed,
      return_type: "TodoApp.Todo",
      arguments: [
        %{name: :todo, type: "TodoApp.Todo", allow_nil?: false}
      ],
      run: %{
        module: :todos,
        function: :mark_completed,
        arity: 1
      }
    }
  ]
}
```

---

## 9. Runtime interop model

## 9.1 Core principle

Gleam functions are invoked through compiled BEAM modules, not interpreted source.

`ash_gleam` resolves the runtime call target directly from the declared module/function/arity reference.

## 9.2 Interop call path

For a Gleam-backed action:

1. Ash receives action invocation.
2. Generated/manual runner extracts arguments.
3. Each argument is marshalled.
4. Interop layer calls compiled Gleam function.
5. Return value is unmarshalled.
6. Runner returns `{:ok, value}` or an Ash error.

## 9.3 Recommended internal modules

- `AshGleam.Interop`
- `AshGleam.Marshal`
- `AshGleam.ManualActionRunner`
- `AshGleam.Error.ActionInterop`

---

## 10. Marshalling rules

## 10.1 Input marshalling

### Scalars

- Elixir scalar → corresponding Gleam-compatible BEAM value

### Nullable values

- `nil` with `allow_nil?: true` → `Option.None`
- non-`nil` value with `allow_nil?: true` → `Option.Some(value)`

### Arrays

- Elixir list → Gleam `List`

### Resources

A resource value is converted according to the generated resource schema.

Only fields supported by `ash_gleam` are marshalled.

The canonical internal operation is:

```elixir
AshGleam.Marshal.to_gleam(resource_module, value)
```

---

## 10.2 Output unmarshalling

### Scalars

- Gleam scalar → Elixir scalar

### Nullable values

- `Option.None` → `nil`
- `Option.Some(value)` → Elixir value

### Arrays

- Gleam `List` → Elixir list

### Resources

Returned Gleam resource-shaped values are converted back into an Elixir map or struct conforming to the declared Ash resource schema.

The canonical internal operation is:

```elixir
AshGleam.Marshal.from_gleam(resource_module, value)
```

---

## 11. Validation rules

Validation should occur as early as possible.

## 11.1 Compile-time/codegen validation

The library must fail fast if any of the following are true:

- a referenced module/function cannot be resolved at compile time
- a resource field uses an unsupported type
- a `gleam_actions` argument/result uses an unsupported type
- a resource argument/result does not use `AshGleam.Resource`
- a declared nullable mapping cannot be represented
- an array contains an unsupported inner type
- a declared action references an unresolved module/function/arity target
- generated type/module naming would collide

## 11.2 Runtime validation

At runtime, the library must detect and raise/wrap errors for:

- missing compiled module
- missing exported function
- arity mismatch
- marshalling failure
- unexpected result shape
- Gleam-side crash or panic

---

## 12. Error model

Interop failures should be wrapped in a dedicated error type.

Illustrative exception:

```elixir
defmodule AshGleam.Error.ActionInterop do
  defexception [:message, :resource, :action, :details]
end
```

Errors should preserve enough structured context to identify:
- the Ash resource
- the Ash action
- the target Gleam module/function
- the phase that failed (`marshal_input`, `call`, `marshal_output`, etc.)

Raw BEAM exceptions should not be exposed without wrapping.

---

## 13. Mix tasks and developer workflow

## 13.1 Installation

```bash
mix igniter.install ash_gleam
```

## 13.2 Code generation task

Primary task:

```bash
mix ash.gleam.codegen
```

Responsibilities:
- load compiled project metadata
- gather manifest entries from resources/domains
- generate Gleam source files
- generate any needed Elixir support modules
- write files to configured output paths

## 13.3 Configuration

Illustrative config:

```elixir
config :ash_gleam,
  output: "src/ash_ffi",
  manifest: ".ash_gleam/manifest.term",
  endpoint_base: "/api/rpc"
```

---

## 14. Generated package layout

Recommended internal structure:

```text
lib/
├─ ash_gleam.ex
├─ ash_gleam/resource.ex
├─ ash_gleam/ffi.ex
├─ ash_gleam/actions.ex
├─ ash_gleam/info.ex
├─ ash_gleam/interop.ex
├─ ash_gleam/marshal.ex
├─ ash_gleam/manual_action_runner.ex
├─ ash_gleam/error/
│  └─ action_interop.ex
├─ ash_gleam/dsl/
│  ├─ resource.ex
│  ├─ ffi.ex
│  ├─ actions.ex
│  └─ gleam_action.ex
├─ ash_gleam/transformers/
│  ├─ validate_resource.ex
│  ├─ collect_types.ex
│  ├─ validate_ffi.ex
│  ├─ write_manifest.ex
│  ├─ validate_gleam_actions.ex
│  └─ generate_manual_actions.ex
├─ ash_gleam/codegen/
│  ├─ manifest.ex
│  ├─ gleam_type_mapper.ex
│  ├─ renderer.ex
│  ├─ writer.ex
│  └─ templates/
│     ├─ model.gleam.eex
│     ├─ ffi_action.gleam.eex
│     └─ transport.gleam.eex
└─ mix/tasks/
   └─ ash.gleam.codegen.ex
```

---

## 15. Example: scalar Gleam-backed action

### Ash DSL

```elixir
gleam_actions do
  action :add, :integer do
    argument :a, :integer, allow_nil?: false
    argument :b, :integer, allow_nil?: false

    run &:math.add/2
  end
end
```

### Gleam implementation

```gleam
pub fn add(a: Int, b: Int) -> Int {
  a + b
}
```

### Internal execution model

Conceptually:

```elixir
defmodule MyApp.Math.GleamActions.Add do
  def run(input, _context) do
    a = AshGleam.Marshal.input!(:integer, input.arguments.a, allow_nil?: false)
    b = AshGleam.Marshal.input!(:integer, input.arguments.b, allow_nil?: false)

    result = AshGleam.Interop.call!("math", :add, [a, b])

    {:ok, AshGleam.Marshal.output!(:integer, result)}
  end
end
```

---

## 16. Example: resource Gleam-backed action

### Ash DSL

```elixir
gleam do
  type_name "Todo"
end

gleam_actions do
  action :mark_completed, __MODULE__ do
    argument :todo, __MODULE__, allow_nil?: false

    run &:todo.mark_completed/1
  end
end
```

### Gleam implementation

```gleam
import ash_ffi/todo.{type Todo}

pub fn mark_completed(todo: Todo) -> Todo {
  Todo(.., completed: True)
}
```

### Semantics

- input `todo` is marshalled according to the generated `Todo` type contract
- the Gleam function returns a `Todo`
- the result is converted back to an Elixir/Ash resource-shaped value
- the action result is returned to the caller
- no persistence is implied in v1

---

## 17. Release scope

## 17.1 v0.1.0 scope

Included:
- resource metadata DSL
- domain FFI DSL
- Gleam-backed action DSL
- manifest generation
- Gleam type generation for supported scalar/resource shapes
- FFI wrapper generation for `:read`, `:create`, `:get`
- scalar and array type interop
- nullable interop via `Option`
- resource interop for AshGleam-enabled resources
- generated/manual action runner support
- structured action interop errors

Excluded:
- relationships and recursive graph marshalling
- authorization-aware field pruning
- update/destroy action generation for FFI
- persistence-aware Gleam-backed update semantics
- exact decimal handling beyond explicitly accepted fallback semantics
- arbitrary custom user-defined interop types
- JavaScript-target Gleam

---

## 18. Design constraints

The following constraints are intentional and normative:

1. `ash_gleam` is schema-driven, not reflection-driven at runtime.
2. Only explicitly declared actions are exported or Gleam-backed.
3. Resource interop requires `AshGleam.Resource` participation.
4. Unsupported types must fail early rather than degrade to untyped behavior.
5. Gleam-backed Ash actions are generic/manual in v1.
6. Runtime execution always targets compiled BEAM modules/functions.

---

## 19. Summary

`ash_gleam` is specified as a BEAM-native Ash extension suite that:

- generates Gleam types from Ash resources
- generates typed Gleam wrappers for selected Ash domain actions
- allows Ash resource actions to execute Gleam functions through explicit DSL
- marshals supported Ash values and AshGleam-enabled resource values across the Elixir/Gleam boundary
- validates aggressively and fails early at compile/codegen time where possible

This is the final v1 spec boundary for the library.

