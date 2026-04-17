# Refactor Roadmap

## Goals

This roadmap turns the high-level cleanup plan into a staged sequence of small, reviewable changes. The main objective is to reduce coupling across type normalization, marshalling, bridge decoding, and code generation without breaking the current public API.

The primary design rule for the refactor is:

- normalize once
- encode/decode in one place
- generate code from explicit specs
- keep runtime semantics out of the renderer

## Current Problems

The main complexity hotspots are:

- `lib/ash_gleam/type_mapper.ex`
- `lib/ash_gleam/marshal.ex`
- `lib/ash_gleam/generated/bridge.ex`
- `lib/ash_gleam/codegen/renderer.ex`

The recurring issues across those files are:

- the same concepts are represented differently in different layers
- raw Ash type checks are duplicated outside the type normalization layer
- marshalling mixes nullable handling, arrays, unions, resources, and error wrapping
- bridge decoding contains runtime semantics instead of just decoding builders
- renderer logic does semantic work that should happen before rendering
- metadata is passed around as unstructured maps and keywords

## Success Criteria

The cleanup is complete when:

- raw type forms like `:atom` and `Ash.Type.Atom` are handled only in the normalization layer
- downstream code branches on normalized forms like `{:constrained_atom, values}`
- marshalling is split into focused modules with narrow responsibilities
- generated bridge code delegates to runtime helpers instead of embedding logic
- renderer consumes explicit specs and mostly formats strings
- error reporting is consistent across runtime and generated paths
- the existing `mix test` suite still passes throughout the refactor

## Guiding Constraints

- keep the public API stable unless there is a strong reason to change it
- prefer incremental PR-sized changes over a single large rewrite
- preserve behavior first, then simplify structure
- add focused tests at each seam before or during extraction
- use `mix test` for verification

## Proposed Architecture

Target module layout:

- `AshGleam.Types`
  - normalized type semantics
- `AshGleam.Spec`
  - resource, field, and action specs
- `AshGleam.Codec`
  - runtime value encoding and decoding
- `AshGleam.Bridge`
  - builder decoding, context extraction, query decoding, result encoding
- `AshGleam.Codegen`
  - rendering and manifest generation only

Suggested runtime module split:

- `AshGleam.Types.Normalized`
- `AshGleam.Spec.Field`
- `AshGleam.Spec.Resource`
- `AshGleam.Spec.Action`
- `AshGleam.Codec`
- `AshGleam.Codec.Value`
- `AshGleam.Codec.Union`
- `AshGleam.Codec.Resource`
- `AshGleam.Bridge.Decode`
- `AshGleam.Bridge.Context`
- `AshGleam.Bridge.Query`
- `AshGleam.Bridge.Result`

The existing modules can remain as compatibility facades until the migration is complete.

## Roadmap

### Phase 0: Baseline and Guardrails

Objective: create a stable baseline before structural changes.

Tasks:

- document current ownership of type normalization, marshalling, bridge decoding, and rendering
- identify public APIs that must remain stable
- add a small set of narrow regression tests around known hotspots
- confirm the full suite passes with `mix test`

Deliverables:

- this roadmap
- a baseline test pass
- explicit list of modules treated as compatibility surfaces

PR size:

- one small PR if extra tests are added now

### Phase 1: Normalize Type Handling in One Place

Objective: make `AshGleam.TypeMapper` the only layer that understands raw Ash type syntax.

Tasks:

- keep raw checks for `:atom` and `Ash.Type.Atom` inside `TypeMapper`
- remove raw atom checks from downstream modules where possible
- introduce helper APIs for common questions, for example:
  - `normalized_type/2`
  - `constrained_atom?/2`
  - `resource_type?/2`
  - `reusable_union?/2`
- migrate downstream branches to use normalized types

Primary files:

- `lib/ash_gleam/type_mapper.ex`
- `lib/ash_gleam/codegen/renderer.ex`
- `lib/ash_gleam/transformers/generate_manual_actions.ex`
- `lib/ash_gleam/transformers/validate_gleam_actions.ex`
- `lib/ash_gleam/marshal.ex`

Exit criteria:

- no downstream module needs to directly check `[:atom, Ash.Type.Atom]`
- normalized forms are the shared contract

Suggested PRs:

1. Add helper APIs to `TypeMapper`
2. Migrate renderer and transformers off raw atom checks
3. Remove leftover duplication

### Phase 2: Introduce Explicit Specs

Objective: replace loose metadata passing with explicit structs.

Tasks:

- define structs for normalized specs:
  - `AshGleam.Spec.Field`
  - `AshGleam.Spec.Resource`
  - `AshGleam.Spec.Action`
  - optionally `AshGleam.Spec.Type`
- convert `Resource.Info` and transformer outputs to build these specs
- replace ad hoc maps like `argument[:type]` and repeated `field.constraints` access with spec accessors

Primary files:

- `lib/ash_gleam/resource/info.ex`
- `lib/ash_gleam/actions/info.ex`
- `lib/ash_gleam/ffi/info.ex`
- `lib/ash_gleam/transformers/generate_manual_actions.ex`
- `lib/ash_gleam/codegen/manifest.ex`
- `lib/ash_gleam/codegen/renderer.ex`

Exit criteria:

- runtime and codegen consume explicit specs instead of raw shape assumptions
- fewer keyword-list and map-key contracts across module boundaries

Suggested PRs:

1. Add spec structs and builders
2. Migrate one consumer path at a time
3. Remove deprecated raw metadata access

### Phase 3: Split Runtime Marshalling into Focused Codecs

Objective: break `AshGleam.Marshal` into small runtime modules with clear responsibility boundaries.

Tasks:

- extract scalar, nullable, and array logic into `AshGleam.Codec.Value`
- extract reusable union logic into `AshGleam.Codec.Union`
- extract resource tuple/map/struct logic into `AshGleam.Codec.Resource`
- keep `AshGleam.Marshal` as a thin compatibility facade during migration

Primary files:

- `lib/ash_gleam/marshal.ex`
- new codec modules under `lib/ash_gleam/codec/`

Exit criteria:

- `Marshal` becomes a delegating wrapper or is replaced entirely
- each codec module has focused unit coverage
- recursive type handling is easier to reason about

Suggested PRs:

1. Extract `Codec.Union`
2. Extract `Codec.Resource`
3. Extract `Codec.Value`
4. Convert `Marshal` into facade and reduce surface area

### Phase 4: Refactor Bridge Runtime Helpers

Objective: move builder decoding concerns into small bridge modules.

Tasks:

- split `AshGleam.Generated.Bridge` into:
  - `Bridge.Decode`
  - `Bridge.Context`
  - `Bridge.Query`
  - `Bridge.Result`
- isolate context extraction from tuple decoding
- isolate filter/sort/limit decoding from builder parsing
- keep generated code calling stable helper functions while internal modules shift

Primary files:

- `lib/ash_gleam/generated/bridge.ex`
- new bridge modules under `lib/ash_gleam/bridge/`

Exit criteria:

- bridge runtime code is separated by concern
- builder parsing no longer hides query semantics and context semantics in the same functions

Suggested PRs:

1. Extract context and result helpers
2. Extract query decoding
3. Extract create/action decoding
4. Keep compatibility wrapper in `Generated.Bridge`

### Phase 5: Reduce Renderer Intelligence

Objective: make code generation consume precomputed specs and helpers instead of deciding runtime behavior.

Tasks:

- move semantic decisions out of `Renderer`:
  - create field filtering
  - import discovery
  - action wiring metadata
  - type branching where possible
- introduce precomputed render inputs so renderer mostly formats modules and functions
- convert large `case ffi.kind` code paths into smaller render helpers if they remain

Primary files:

- `lib/ash_gleam/codegen/renderer.ex`
- `lib/ash_gleam/codegen/manifest.ex`

Exit criteria:

- renderer primarily renders
- runtime semantics are owned by spec and bridge layers
- codegen becomes easier to snapshot-test

Suggested PRs:

1. Precompute bridge render specs
2. Move import computation out of renderer
3. Reduce action-kind rendering branches

### Phase 6: Standardize Error Handling

Objective: make failures consistent and structured across interop, marshalling, and bridge paths.

Tasks:

- define a shared interop/error model with phases such as:
  - `:normalize`
  - `:encode_input`
  - `:decode_input`
  - `:interop_call`
  - `:decode_output`
  - `:bridge_decode`
- align `Marshal`, `Interop`, bridge helpers, and `GleamActionRunner` around it
- preserve structured details instead of flattening to strings too early

Primary files:

- `lib/ash_gleam/error/action_interop.ex`
- `lib/ash_gleam/interop.ex`
- `lib/ash_gleam/marshal.ex`
- `lib/ash_gleam/gleam_action_runner.ex`
- bridge runtime modules

Exit criteria:

- errors carry consistent phases and context
- generated and non-generated paths report failures the same way

Suggested PRs:

1. Define shared error shape
2. Migrate interop and marshal
3. Migrate bridge and action runner

### Phase 7: Reorganize the Folder Layout

Objective: align file layout with actual responsibilities.

Tasks:

- move modules into grouped directories:
  - `lib/ash_gleam/types/`
  - `lib/ash_gleam/spec/`
  - `lib/ash_gleam/codec/`
  - `lib/ash_gleam/bridge/`
  - keep `codegen/`, `dsl/`, and `transformers/`
- leave compatibility aliases or wrappers where needed until follow-up cleanup lands

Primary files:

- all affected modules

Exit criteria:

- a new contributor can find type logic, codec logic, and bridge logic by directory

Suggested PRs:

1. Move new modules first
2. Add compatibility wrappers
3. Remove wrappers once callers are migrated

### Phase 8: Tighten Tests Around the New Seams

Objective: replace some broad implicit coverage with explicit boundary coverage.

Add tests for:

- type normalization matrix
- constrained atom normalization and Gleam type naming
- scalar/nullable/array codec behavior
- reusable union payload validation
- resource round-tripping
- bridge context extraction
- filter/sort/limit decoding
- rendered module snapshots or structural assertions

Primary files:

- `test/ash_gleam/runtime_test.exs`
- `test/ash_gleam/ffi_test.exs`
- new focused test modules for codec, bridge, and type normalization

Exit criteria:

- each extracted seam has targeted tests
- integration tests still pass

Suggested PRs:

- add tests alongside each extraction PR rather than all at the end

## Recommended PR Sequence

This is the sequence I would actually use:

1. Add focused tests around `TypeMapper`, `Marshal`, and `Generated.Bridge`
2. Centralize raw type handling in `TypeMapper`
3. Add explicit spec structs and migrate one consumer path
4. Extract `Codec.Union`
5. Extract `Codec.Resource`
6. Extract `Codec.Value`
7. Convert `Marshal` into thin facade
8. Extract bridge context and result helpers
9. Extract bridge query helpers
10. Extract bridge decode helpers
11. Precompute render specs and simplify `Renderer`
12. Standardize error handling
13. Reorganize directories and compatibility wrappers
14. Remove deprecated helpers and wrappers

## First PR Recommendation

The first PR should be intentionally narrow and high leverage.

Scope:

- add focused regression tests around type normalization and marshalling
- centralize raw atom handling in `TypeMapper`
- remove downstream raw checks where straightforward

Why this first:

- it attacks duplicated semantics without forcing a full redesign
- it reduces confusion immediately
- it creates a clean foundation for specs and codec extraction

Candidate files for PR 1:

- `lib/ash_gleam/type_mapper.ex`
- `lib/ash_gleam/codegen/renderer.ex`
- `lib/ash_gleam/transformers/generate_manual_actions.ex`
- `lib/ash_gleam/transformers/validate_gleam_actions.ex`
- related tests

## Review Checklist for Each PR

For each refactor PR, check:

- is one responsibility being moved into one clear owner?
- did the public API remain stable?
- did raw type checks decrease?
- did any module become simpler, or did complexity merely move?
- were targeted tests added for the extracted seam?
- does `mix test` still pass?

## Risks

The main refactor risks are:

- changing wire format behavior accidentally
- changing generated code behavior while simplifying renderer internals
- breaking tuple or context handling in bridge code
- introducing parallel type systems during migration

Risk mitigation:

- keep compatibility facades while migrating
- add seam-level tests before large moves
- prefer extracting logic first, renaming and moving second
- avoid changing generated wire shape until dedicated tests exist

## Defer Until Later

These should not be part of the first cleanup wave unless they block the work:

- public API redesign
- DSL redesign
- feature additions to supported types
- major codegen output redesign
- performance tuning without evidence of a bottleneck

## Definition of Done

The roadmap is complete when:

- `TypeMapper` is the single source of truth for raw Ash type interpretation
- explicit specs replace most unstructured metadata passing
- codec and bridge responsibilities are split into focused modules
- renderer mostly formats instead of deciding semantics
- error handling is consistent
- directory layout reflects ownership
- `mix test` passes after each phase and at the end
