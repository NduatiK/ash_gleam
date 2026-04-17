# Domain Code Interface Plan

Under the hood, this feature depends on the API in changeset.md, implement that first.

## Goal

Add a domain-level DSL for generating code-interface functions that persist resource updates by:

1. running a declared Gleam action on an existing record
2. diffing the original and proposed resource values
3. building an `Ash.Changeset` with a configured update action
4. executing the update through the domain-facing interface

This depends on resource-side Gleam actions carrying enough metadata to identify which actions are intended to propose updates for an existing resource.

Target DSL:

```elixir
defmodule AshGleam.TestDomain do
  use Ash.Domain,
    otp_app: :ash_gleam,
    extensions: [AshGleam.DomainExtension]

  resources do
    resource AshGleam.TestTodo do
      define_gleam_update :mark_completed, action: :update

      define_gleam_update :increase_priority,
        gleam_action: :increase_priority_by_one,
        action: :update
    end
  end
end
```

## Desired Behavior

Generated domain functions should look and behave like normal Ash code interfaces:

```elixir
AshGleam.TestDomain.mark_completed(todo, %{other_arg: 1})
AshGleam.TestDomain.mark_completed!(todo, %{other_arg: 1})
```

Execution flow:

1. call the configured Gleam action on the resource, passing the original record plus provided params
2. receive the proposed updated resource
3. compute `AshGleam.Diff.resource_changes(original, proposed)`
4. build `Ash.Changeset.for_update(original, configured_action, changes, opts)`
5. persist with `Ash.update/2` or `Ash.update!/2`

This keeps the public API high-level while preserving a lower-level explicit changeset API elsewhere.

## Resource Action Metadata Requirement

The current `gleam.actions` DSL does not distinguish:

- ordinary Gleam-backed actions
- Gleam actions that propose updates to an existing resource

That distinction needs to exist on the resource before the domain code interface can safely generate update helpers.

Proposed resource-side addition:

```elixir
gleam do
  actions do
    action :mark_completed, __MODULE__ do
      update? true
      argument :todo, __MODULE__, allow_nil?: false
      run &:todo_logic.mark_completed/1
    end
  end
end
```

Required semantics for `update? true`:

- the action is intended to return a proposed updated version of the same resource
- the first argument must be the resource itself
- the return type must be the resource module
- the action may have additional arguments after the resource argument

This makes the domain DSL validate against explicit resource metadata instead of inferring behavior from argument and return types alone.

## DSL Design

Introduce a new domain extension, likely `AshGleam.DomainExtension`, with a nested entity under each domain `resource` entry.

Proposed entity:

```elixir
define_gleam_update :mark_completed, action: :update
```

Fields:

- `name` - generated domain function name
- `action` - Ash update action to persist with; required
- `gleam_action` - optional resource Gleam action name; defaults to `name`
- `args` - optional future enhancement if we want explicit argument ordering beyond `record, params`
- `description` - optional docs support if desired later

Validation rules:

- referenced resource must define the configured `gleam_action`
- referenced resource action must be a Gleam-backed action marked `update? true`
- referenced resource action must take the resource as its first argument
- referenced resource action must return the resource type
- persistence `action` must exist and be an Ash update action
- generated function name must not collide with existing code interfaces on the domain

## Generated API Shape

Generate both non-bang and bang functions on the domain:

```elixir
def mark_completed(record, params \\ %{}, opts \\ [])
def mark_completed!(record, params \\ %{}, opts \\ [])
```

Recommended semantics:

- `record` is the original persisted resource
- `params` is a map of non-record Gleam action arguments
- the record argument is inserted into the Gleam action params automatically as the first action argument
- `opts` passes through to Ash update execution where appropriate

## Runtime Implementation

Add a reusable runtime helper rather than inlining logic into generated functions.

Proposed helper:

```elixir
AshGleam.CodeInterface.gleam_update(resource, record, gleam_action, params, update_action, opts)
```

Responsibilities:

1. build params for the resource Gleam action, inserting the original record into the first argument slot
2. invoke the resource Gleam action through its existing generated/manual action interface
3. extract the proposed record from the result
4. compute diff via `AshGleam.Diff.resource_changes/2`
5. build and persist the configured Ash update action

This avoids duplicating update semantics across generated domain functions.

## Changeset API Relationship

Keep a lower-level changeset-focused API in parallel, likely:

```elixir
record
|> AshGleam.Changeset.for_update(:mark_completed, %{other_arg: 1}, action: :update)
|> Ash.update!()
```

The domain code interface should be the convenience layer.
The changeset helper should remain the explicit composable layer.

## Codegen / Transformer Work

Implementation tasks:

1. Extend the resource `gleam.actions` DSL with update metadata, likely `update?`.
2. Add resource-side verifier rules for `update? true`:
   - first argument is the resource
   - return type is the resource
3. Add domain DSL entities and info helpers for `gleam_update`.
4. Add domain verifier(s) for resource/action/action-type existence and naming collisions.
5. Add transformer(s) that generate domain functions.
6. Add runtime helper module used by generated functions.
7. Reuse existing resource Gleam action metadata instead of duplicating type knowledge.

Prefer generating ordinary Elixir domain functions directly, following the same style already used for resource-side generated interfaces.

## Open Design Decisions

Resolve these before implementation:

1. Should generated functions accept only `%{}` params, or also keyword lists?
2. Should `opts` be forwarded to the inner Gleam action call, the outer Ash update, or both?
3. Should authorization/actor be applied only at persistence time, or also when invoking the Gleam action?
4. How should nil/no-op diffs behave:
   - return the original record unchanged
   - build an empty update changeset
   - short-circuit without `Ash.update`
5. Should code interfaces also generate a `*_changeset` variant, or keep that only in `AshGleam.Changeset`?
6. Should `update? true` imply “first argument is resource” by convention, or should there also be an explicit resource argument name field for better error messages?

## Testing Plan

Add tests for:

- resource validation rejects `update? true` actions unless the first argument is the resource
- resource validation rejects `update? true` actions unless the return type is the resource
- successful generated interface with matching Gleam and Ash update actions
- `gleam_action:` override behavior
- bang and non-bang variants
- diff-based persistence changes only modified writable fields
- validation when `action:` is missing
- validation when the target persistence action is not an update action
- validation when the target Gleam action does not exist
- validation when the target Gleam action exists but is not marked `update? true`
- validation when generated names collide
- behavior with additional non-record params
- behavior when Gleam action returns an invalid shape for update persistence

## Documentation Plan

After implementation:

1. document the domain extension in `README.md`
2. document resource-side `update? true` semantics in `gleam.actions`
3. show side-by-side low-level changeset API and high-level domain code-interface API
4. clarify that domain code interfaces persist, while `AshGleam.Changeset.for_update/...` only builds a changeset
