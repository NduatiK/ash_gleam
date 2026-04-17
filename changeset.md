# Changeset Diff Plan

## Goal

Add a low-level API for building an `Ash.Changeset` from the diff between:

- an original persisted resource record
- a proposed updated resource returned by a Gleam action

Target API:

```elixir
todo
|> AshGleam.Changeset.for_update(:mark_completed, %{other_arg: 1}, action: :update)
|> Ash.update!()
```

This API should be explicit about one thing:
it creates a changeset, but does not persist anything by itself.

## Desired Behavior

Execution flow:

1. take an existing resource record
2. run a resource Gleam action that is marked as an update-style action
3. receive the proposed updated version of that same resource
4. compute `AshGleam.Diff.resource_changes(original, proposed)`
5. build `Ash.Changeset.for_update(original, configured_action, changes, opts)`

The caller decides whether to:

- persist with `Ash.update/2` or `Ash.update!/2`
- inspect or modify the changeset further
- use the diff result in custom workflows

## Resource Action Requirement

This API depends on certain Gleam actions being explicitly marked as update-style actions at the resource level.

Proposed resource DSL:

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

- the action proposes an updated version of the same resource
- the first argument is the resource
- the return type is the resource
- additional arguments may follow the resource argument

Without this metadata, `AshGleam.Changeset.for_update/4` would have to infer too much from generic Gleam action definitions.

## Proposed API Shape

Primary API:

```elixir
AshGleam.Changeset.for_update(record, gleam_action, params \\ %{}, opts \\ [])
```

Example:

```elixir
todo
|> AshGleam.Changeset.for_update(:mark_completed, %{other_arg: 1}, action: :update)
|> Ash.update!()
```

Recommended semantics:

- `record` is the original persisted resource
- `gleam_action` is the name of a resource Gleam action marked `update? true`
- `params` is a map of non-record arguments
- the original record is injected as the first Gleam action argument automatically
- `opts[:action]` selects the Ash update action used to build the changeset

`action:` should be required. Do not silently default to `:update`.

## Runtime Helper

Add a helper module for the internal workflow:

```elixir
AshGleam.Changeset.for_update(record, gleam_action, params, opts)
```

Responsibilities:

1. look up the resource’s Gleam action metadata
2. verify the target action is marked `update? true`
3. build params for the action by inserting the original record as the first argument
4. invoke the resource Gleam action through the existing resource action path
5. extract the proposed updated resource
6. compute `AshGleam.Diff.resource_changes(original, proposed)`
7. build and return `Ash.Changeset.for_update(original, ash_action, changes, ash_opts)`

This keeps the diffing and action invocation logic out of callers.

## Validation Rules

`AshGleam.Changeset.for_update/4` should fail clearly when:

- `opts[:action]` is missing
- the target Gleam action does not exist
- the target Gleam action is not marked `update? true`
- the target persistence action does not exist
- the target persistence action is not an Ash update action
- the Gleam action does not return the expected resource shape

Resource-side validation should also reject `update? true` actions unless:

- the first argument is the resource
- the return type is the resource

## Open Design Decisions

Resolve these before implementation:

1. Should extra `opts` be forwarded only to `Ash.Changeset.for_update`, or also to the inner Gleam action invocation?
2. Should authorization/actor only matter when the caller eventually persists, or should some opts be applied during the Gleam action run as well?
3. How should no-op diffs behave:
   - return an empty update changeset
   - short-circuit and return the original record somehow
   - always build a changeset and let Ash decide

## Implementation Tasks

1. Add `update?` metadata to resource `gleam.actions`.
2. Add resource-side validation for update-style Gleam actions.
3. Add `AshGleam.Changeset` module or extend it if it already exists.
4. Implement `for_update/4`.
5. Reuse existing Gleam action execution machinery instead of reimplementing interop.
6. Normalize and separate opts intended for the Ash update action from opts used internally.
7. Return a plain `Ash.Changeset` ready for `Ash.update/2`.

## Testing Plan

Add tests for:

- building a valid changeset from an update-style Gleam action
- diff output includes only changed writable attributes
- additional non-record params are passed correctly
- `action:` is required
- target persistence action must be an Ash update action
- target Gleam action must exist
- target Gleam action must be marked `update? true`
- invalid Gleam return shape raises a clear error
- no-op diffs behave according to the chosen policy
- callers can still modify the returned changeset before persistence

## Documentation Plan

After implementation:

1. document `AshGleam.Changeset.for_update/4` in `README.md`
2. clarify that it only builds a changeset
3. show how it relates to the higher-level domain code-interface plan in `code_interface.md`
