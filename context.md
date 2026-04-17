

---

Claude:
• Yes, I think that is the right direction.

If Gleam can call arbitrary Elixir FFI without an explicit context object, then any authorization story is weak by construction. You lose actor,
tenant, tracer, authorization mode, and any future request-scoped state exactly at the boundary where it matters most.

I’d recommend making FFI context mandatory, not optional.

A good shape is:

pub type Context

@external(erlang, "Elixir.MyApp.Generated", "some_call")
pub fn some_call(ctx: Context, arg1: String) -> Result(Int, String)

And then every generated Gleam action gets that context as an input too, probably first:

pub fn mark_completed(ctx: Context, todo: Todo) -> Todo

Why I think this is the best design:

- it makes authorization-capable calls explicit in every FFI usage
- it prevents “naked” FFI calls that accidentally bypass actor/tenant checks
- it gives you one transport for all execution metadata, not just actor
- it scales to tracing, locale, request id, tenant, authorization flags, and feature gates later

- tenant
- authorize?
- tracer
- maybe domain / resource / action
- anything else you need for nested Ash calls

A few concrete recommendations:

- Require context for all generated FFI functions.
- Pass context into all Gleam-backed Ash actions automatically.


1. Generated Gleam actions receive ctx: Context as their first argument.
2. Generated FFI bindings require ctx: Context as their first argument.
3. Elixir creates and validates the context object.
4. Any Ash-aware Elixir operation reached through FFI must read actor/tenant/etc from that context, never from globals or ad hoc params.

That is the cleanest way to make permissions and nested FFI calls composable instead of best-effort.

If you want, I can turn this into a short ffi_context.md design brief next.

---
Me:
I'll clarify something, Ash policies will always apply and protect resources and actions. So that's not a concern.
I also don't want to create a API that always requires context to be passed in. It seems like a good idea but if all I'm doing is some mathematics inside of gleam I don't want to always have to think about context. Is that an unreasonable desire or should I just accept to always pass in a context?