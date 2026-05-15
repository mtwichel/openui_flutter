---
date: 2026-05-14
topic: each-named-loop-var
---

# `@Each` named loop variable

## What We're Building

Reshape `@Each` to take an explicit, author-named loop variable as a string second argument, replacing the implicit `$item` binding. New signature:

```
@Each(list, "name", template)
```

Inside `template`, the loop variable is a bare IDENT (`name.field`, not `$name.field`). The index is still surfaced as the existing `$index` STATEVAR. The two-argument form `@Each(list, template)` is removed — the parser and evaluator both reject it with a clear error pointing at the new shape. `@Map` and `@Filter` keep their current `($list, $item / $index)` signature; this change is scoped to `@Each` only.

This is a breaking change to a JS-reference-parity builtin. There are no demo scripts, prompt snippets, or production callers exercising the old form yet — only the `builtins_test.dart` suite — so the migration burden is contained to test rewrites and the `lang-reference.md` doc.

## Why This Approach

Three shapes were considered:

1. **Replace entirely (3-arg only)** — *chosen*. One signature, no overload ambiguity, smallest spec surface for the streaming parser to validate. The 2-arg form has zero in-tree consumers outside tests, so the cost is one-time test rewrite.
2. **Coexist (overload by arity)** — rejected. Two ways to iterate means two prompt examples, two parse paths, and a fork of the iteration helper. Pure churn for a feature with no production callers on the old form.
3. **Replace with a deprecation-style error** — rejected as a separate option but folded in: replacement *does* surface a targeted error message when the parser sees the old 2-arg shape, so authors get a useful pointer rather than a generic "wrong arity" complaint.

The named-loop form also makes `Tag(t.priority, …)`-style templates legible at a glance, which is the actual ergonomic win: bare IDENTs read as "this is the row I'm holding," while `$item.priority` reads as global state.

## Key Decisions

- **Signature:** `@Each(list, "name", template)`. Exactly 3 args. — Single shape, no arity dispatch, no optional positional.
- **Loop variable kind:** bare IDENT (`Reference` AST node), not STATEVAR. — Matches the user-facing example (`t.priority`) and keeps iteration vars distinct from reactive state.
- **Index access:** unchanged. `$index` is still bound inside the template body. — Avoids introducing a second optional name string or a `<name>_index` convention; consistent with `@Filter` / `@Map`, which keep `$item`/`$index`.
- **Scope of change:** `@Each` only. `@Map` and `@Filter` keep `$item`/`$index`. — User asked for the smaller change; `@Map`/`@Filter` are used predicate-style and the named-loop form has less ergonomic payoff there.
- **Validation site:** both parser and evaluator. — Parser rejects non-string-literal arg-2 with `ParseError` so the streaming parser can surface the error before evaluation. Evaluator re-validates so direct AST construction paths can't bypass it.
- **Streaming parser safety:** the 3-arg arity check and the string-literal check fire only on statements the streaming parser has committed (i.e., after the autoclose pass settles). Mid-stream forms like `@Each(rows, "t")` with the third argument still pending are not `ParseError`s. — Without this gate, every keystroke during streaming would surface false errors and break the streaming UX.
- **Name rules:** must match `[a-z_][a-zA-Z0-9_]*` *and* not be a reserved keyword (`true`, `false`, `null`). Empty string rejected. — Mirrors the lexer's IDENT rule; prevents confusing aliases like `"$item"` or `"true"`.
- **Shadowing:** loop variable shadows any statement of the same name inside the template body. — Standard scoping. `EvalContext.withIteration` already layers iteration vars over the statement map; same mechanism extends naturally.
- **Null and non-list inputs:** `null` list returns `[]` silently. A non-list value emits an `EvaluationError` and returns `[]`. — Inherits the current `@Each` semantics unchanged; the change is to the signature, not to the input-type contract.
- **Removal of the 2-arg form:** the existing 2-arg `@Each(list, template)` form is removed. The evaluator emits an `EvaluationError` with a message pointing at the new 3-arg shape, so any programmatic AST-construction caller gets a direct pointer instead of a generic "wrong arity." — Replacement is breaking; there are no in-tree consumers outside tests.

## Notes for the planner

Load-bearing anchors only. Implementation strategy belongs in the plan.

- Iteration vars are stored under the bare IDENT key (no `$` prefix), distinct from the `$item`/`$index` keys used by `@Map`/`@Filter`.
- `Reference("name")` must consult `iterationVars` before falling through to the statement map. `_evalReference` doesn't currently do that — only `_evalStateRef` does.
- Parser-level string-literal validation fits the same hook site as the recent `x-action` array validation.
- `BuiltinCall` AST stays unchanged. Only `@Each`'s handler and the parser's per-builtin shape check shift.
- Files in scope: `packages/openui_core/lib/src/eval/builtins.dart`, the parser (per-builtin validation site), `packages/openui_core/test/src/eval/builtins_test.dart` (rewrites for `@Each` only), and `docs/lang-reference.md`.

## Open Questions

- **Nested `@Each`:** `@Each(outer, "o", @Each(o.children, "c", …))` — confirm the inner iteration vars layer correctly over the outer ones. `withIteration` already does parent-merge, so this should work, but it deserves a dedicated test.
- **`$index` inside nested `@Each`:** the inner loop overwrites the outer's `$index`. Acceptable for v0.1, but the planner should note it; a future `@Each(list, "name", "idx", tpl)` form could be added non-breakingly.
- **Renderer / materializer integration:** confirm `packages/openui/lib/src/renderer.dart` and `packages/openui_core/lib/src/parser/materialize.dart` don't special-case `@Each` result expansion in a way the loop-variable rename would disturb. The current path runs `@Each` through the evaluator and consumes a `List<Object?>`, which the rename shouldn't affect — but verify before locking the plan.
- **System prompt:** no current prompt mentions `@Each`. Decide during planning whether to add a short iteration section to `openUiLangSystemPrompt` in the example app, or defer until the renderer has a visible iteration use case.
- **JS reference parity:** confirm the upstream JS implementation uses exactly this signature shape before locking the spec — the commit history mentions "JS reference parity" as a recent direction.
