One more thing to think about and I want your advice on this. Gleam has the ability to call Elixir functions using gleam FFI, but this doesn't
really give us any context which can be used for checking whether those call are allowed. I would want to always pass in a context opaque type
which will be internally be the options that the gleam action received (things like the actor) and have these passed down into the FFI function
calls. They should be required for the ffi calls to happen.


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
- it keeps the Gleam side honest: if a function can reach Elixir, it must have context

I would make the context opaque in Gleam and only construct it from generated entrypoints. Gleam code should be able to pass it around, but not
inspect or forge it.

Internally, the opaque value can wrap the Ash opts/input context you already have, for example:

- actor
- tenant
- authorize?
- tracer
- maybe domain / resource / action
- anything else you need for nested Ash calls

A few concrete recommendations:

- Require context for all generated FFI functions.
- Pass context into all Gleam-backed Ash actions automatically.
- Store the original Ash options/context inside it, not a reduced subset.
- Reject FFI calls that do not receive a valid context token.
- Keep the token opaque on the Gleam side and validated on the Elixir side.

The one design decision I would be strict about is this: don’t model the context as “just a map of opts” on the Gleam side. Make it a dedicated
opaque type. Otherwise people will start depending on its structure, and you’ll lose the ability to change it safely.

So my recommendation is:

1. Generated Gleam actions receive ctx: Context as their first argument.
2. Generated FFI bindings require ctx: Context as their first argument.
3. Elixir creates and validates the context object.
4. Any Ash-aware Elixir operation reached through FFI must read actor/tenant/etc from that context, never from globals or ad hoc params.

That is the cleanest way to make permissions and nested FFI calls composable instead of best-effort.

If you want, I can turn this into a short ffi_context.md design brief next.

---
I'll clarify something, Ash policies will always apply and protect resources and actions. So that's not a concern.
I also don't want to create a API that always requires context to be passed in. It seems like a good idea but if all I'm doing is some mathematics inside of gleam I don't want to always have to think about context. Is that an unreasonable desire or should I just accept to always pass in a context?