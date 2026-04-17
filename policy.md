# Gleam Action Policy Brief

## Goal

Extend `AshGleam` so Ash authorization policies can apply to Gleam-backed actions in the same way they apply to ordinary Ash actions.

This should cover:

- resource `gleam.actions`
- update-style Gleam actions used by `AshGleam.Changeset.for_update/4`
- any future domain code interfaces built on top of those actions

## Principle

Gleam actions should not bypass Ash authorization just because the action body lives in Gleam.

The policy model should stay Ash-native:

- authorization is evaluated using the resource action definition
- actor and tenant context come from the Ash input/query/changeset
- policy failures return normal Ash authorization errors

## Desired Behavior

When a Gleam-backed action is invoked through Ash:

1. the resource action is resolved normally
2. Ash authorization runs against that action before the Gleam function is executed
3. if authorized, the Gleam function runs
4. if forbidden, the Gleam function does not run

For update-style Gleam actions used to build changesets:

1. authorization should apply when the Gleam action is called
2. authorization should also apply later when the resulting Ash update action is persisted

This means the “propose update” step and the “persist update” step can each have their own policy checks.

## Resource-Side Design

Keep policy attachment on the Ash action, not on a separate Gleam-only policy system.

Proposed direction:

- resource `gleam.actions` continue generating real Ash actions
- those generated Ash actions participate in the normal authorizer pipeline
- resource authors define policies against those action names exactly as they would for non-Gleam actions

Example:

```elixir
policies do
  policy action(:mark_completed) do
    authorize_if relates_to_actor_via(:owner)
  end
end
```

That should work whether `:mark_completed` is implemented in Elixir or Gleam.

## Metadata Requirement

For update-style Gleam actions, resource metadata should indicate that an action proposes a modified version of the same resource.

Proposed resource DSL:

```elixir
action :mark_completed, __MODULE__ do
  update? true
  argument :todo, __MODULE__, allow_nil?: false
  run &:todo_logic.mark_completed/1
end
```

This metadata matters for policy enforcement because:

- the first step authorizes execution of the Gleam action itself
- the second step authorizes persistence through a separate Ash update action

## Runtime Enforcement

No separate policy engine should be introduced.

Instead:

1. Gleam-backed resource actions should be invoked through the normal Ash action execution path.
2. The existing Ash authorizer stack should run before interop calls into Gleam.
3. Any helper such as `AshGleam.Changeset.for_update/4` should call the Gleam action through Ash, not by directly calling interop helpers.
4. Any higher-level domain code interface should persist through `Ash.update/2` or `Ash.update!/2`, so normal update-action policies also apply.

This preserves a single source of truth for authorization.

## Validation Rules

Add validation that:

- policy-enabled resources can declare policies against Gleam-backed actions by name
- helper APIs do not bypass Ash action execution when authorization should apply
- update-style helpers require an explicit persistence action so the second authorization boundary is clear

## Open Questions

1. Should `AshGleam.Changeset.for_update/4` require actor context up front, or only when the caller later persists?
2. If the Gleam action itself loads related data through Elixir FFI calls, should those nested calls enforce actor context separately?
3. Should there be a way to mark certain Gleam actions as internal-only so no public code interface is generated for them?
4. Do we want separate docs guidance for “policy on propose step” versus “policy on persist step”?

## Implementation Outline

1. Confirm generated Gleam-backed resource actions already execute through normal Ash action flow.
2. Add tests proving policy checks run before the Gleam function executes.
3. Ensure `AshGleam.Changeset.for_update/4` invokes the Gleam action through Ash rather than raw interop.
4. Ensure any future domain code-interface helper preserves both authorization boundaries.
5. Document the pattern in `README.md`.

## Test Plan

Add tests for:

- a policy allowing a Gleam-backed action
- a policy forbidding a Gleam-backed action
- proving the Gleam function is not executed when authorization fails
- update-style Gleam action allowed but persistence action forbidden
- update-style Gleam action forbidden before diffing begins
- actor context flowing correctly through helper APIs
