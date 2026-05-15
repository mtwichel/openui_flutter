---
title: "feat(openui_core)!: @Each named loop variable"
type: feat
date: 2026-05-14
brainstorm: docs/brainstorm/2026-05-14-each-named-loop-var-brainstorm-doc.md
---

## feat(openui_core)!: `@Each` named loop variable - Standard

## Overview

Reshape `@Each` so authors name the loop variable explicitly. New signature:

```
@Each(list, "name", template)
```

Inside `template`, the loop variable is a bare IDENT (`name.field`), bound through the existing `iterationVars` map under the unprefixed key. `$index` is still bound. The 2-arg `@Each(list, template)` form (with implicit `$item`) is removed. `@Map` and `@Filter` keep their current `($list, $item / $index)` signature; this change is scoped to `@Each`.

This is a breaking change to one functional builtin. The only in-tree consumers are `builtins_test.dart`, the renderer's iteration path in `packages/openui/lib/src/renderer.dart`, and `docs/lang-reference.md`.

## Problem Statement / Motivation

The implicit `$item` binding makes nested `@Each` and `Tag(t.priority, …)`-style templates hard to read: every reference looks like a global state read. The named-loop form makes iteration vars visually distinct from store state, matches the JS reference, and lets a single template declare what each row is called. Removing the 2-arg form keeps the spec surface and the streaming parser's per-builtin validation single-shape.

## Proposed Solution

Five edits, all in `packages/openui_core` plus the renderer and the language reference.

1. **AST stays as-is.** `BuiltinCall(name, args, offset)` already carries a variadic arg list. No new node kinds.
2. **Evaluator: `_evalReference` consults `iterationVars` first.** When `iterationVars[name]` is present (unprefixed key), return it. Otherwise fall through to the statement map. `$item`/`$index` lookups continue to flow through `_evalStateRef`, which uses the `$`-prefixed key — both kinds of keys coexist in the same map.
3. **`@Each` handler in `builtins.dart`:**
   - Require exactly 3 args. Evaluator re-validates the same shape the parser validates — the parser can be bypassed by direct AST construction in tests and (future) programmatic callers, so the evaluator is the source-of-truth backstop.
   - `args[0]`: list. Null → `[]`. Non-list → `EvaluationError`, return `[]`.
   - `args[1]`: must be a `Literal` whose `value` is a non-empty `String` matching `[a-z_][a-zA-Z0-9_]*` and not `true`/`false`/`null` and not starting with `$`. Any failure → `EvaluationError("@Each requires (list, \"name\", template) — second arg must be a string identifier literal")`, return `[]`.
   - `args[2]`: template. Evaluated per item with `iterationVars` extended by `{name: item, "$index": i}`.
   - Wrong arity (≠ 3) → `EvaluationError` pointing at the new shape.
   - `@Map` and `@Filter` unchanged — they continue to use the shared `_iterate` helper after splitting `@Each` off into its own path.
4. **Parser-level validation:** add a private function in `parser.dart` — `_validateEachShape(Statement statement, {int? committedOffsetBoundary})` — that walks the statement's expression for `BuiltinCall(name: "@Each")` nodes and emits a `ParseException` when arity ≠ 3 or `args[1].value` is not a `Literal<String>` matching the IDENT rule. Singular naming on purpose — no generalization for other builtins until another one needs the same hook. `parseProgram` calls it on every completed statement with no boundary (everything strict) and appends results to `Program.errors`. `StreamParser._compute` calls `parseProgram` and then re-runs the validation pass with `committedOffsetBoundary: split.prefix.length`, replacing the parser-emitted `@Each`-shape errors with the offset-gated set. Statements whose `offset >= committedOffsetBoundary` are skipped — those are in the autoclose tail and may still be mid-typing. Existing `program.errors` from parser recovery flow through unchanged; only `@Each`-shape errors are filtered.
5. **Renderer: update the iteration path** in `packages/openui/lib/src/renderer.dart` so `@Each` reads its template from `args[2]`, binds the named loop var into `iterationVars[name]`, and still binds `$index`. `@Map`'s path keeps reading `args[1]` as its template with `$item`/`$index`. Split `_isIterating(call)` into per-builtin handling, or branch on `call.name` inside `_renderIteration` and `_resolvePropValue`.

### File touch list

| File | Change |
|---|---|
| `packages/openui_core/lib/src/eval/builtins.dart` | Split `@Each` off `_iterate`. New `_evalEach` with 3-arg + name-literal validation. Updates registry doc comment. |
| `packages/openui_core/lib/src/eval/evaluator.dart` | `_evalReference` checks `context.iterationVars` (unprefixed key) before the statement map. |
| `packages/openui_core/lib/src/parser/parser.dart` | New private function `_validateEachShape(Statement, {int? committedOffsetBoundary})` invoked from `parseProgram`. Errors get added to `Program.errors`. |
| `packages/openui_core/lib/src/parser/streaming.dart` | After `parseProgram`, re-run `_validateEachShape` with `committedOffsetBoundary: split.prefix.length` and replace the parser's `@Each`-shape errors with the gated set. |
| `packages/openui/lib/src/renderer.dart` | `_renderIteration` branches on `call.name`: `@Each` reads `args[2]` and binds the named var via `iterationVars[name]`; `@Map` keeps the existing 2-arg path. `_resolvePropValue` widget-iteration branch adjusts its `args[1].value is CompCall` check to `args[2]` for `@Each`. |
| `packages/openui_core/test/src/eval/builtins_test.dart` | Rewrite the `@Each` group for the 3-arg form. Add tests for named var, `$index` retention, nested `@Each` with distinct names, invalid name strings, missing name, wrong arity, `$`-prefixed name rejected. Keep `@Map`/`@Filter` groups unchanged. |
| `packages/openui_core/test/src/parser/parser_test.dart` | Add: 3-arg `@Each` parses cleanly; 2-arg `@Each` surfaces a `ParseException` from `parseProgram.errors` whose message contains `"3 args"` and `"string identifier"` (pin the wording so the streaming filter contract stays stable); non-string-literal second arg surfaces a `ParseException`. |
| `packages/openui_core/test/src/parser/streaming_test.dart` | Add: mid-stream `@Each(rows, "t"` (autoclose-patched) does not surface a builtin-shape error; committed-region invalid `@Each` does. |
| `packages/openui_core/test/src/parser/materialize_test.dart` | Update the `@Each(target, row)` reachability case at `:280` to the 3-arg form `@Each(target, "r", row)`. The `BuiltinCall('@Each', const [], ...)` empty-args case at `:92` exercises only `typeName` and stays unchanged. |
| `packages/openui/test/src/renderer_test.dart` | Update existing widget-iteration test(s) to the 3-arg form. Add a new test exercising the `_resolvePropValue` widget-branch: a component prop whose value is `@Each(items, "row", Card(title: row.name))`. |
| `docs/lang-reference.md` | Update the `@Each` row signature and semantics. Add an iteration note about the named loop var and `$index`. |
| `packages/openui_core/lib/src/prompt/prompt.dart` | Add one grammar-primer line about `@Each(list, "name", template)` so the LLM emits the new shape. |
| `packages/openui_core/CHANGELOG.md` | Document the breaking change. |
| `packages/openui/CHANGELOG.md` | One-line entry under the unreleased section noting the renderer's iteration path now reads the template from `args[2]` for `@Each` (consumer-observable). |

## Technical Considerations

- **Architecture.** Iteration scope is already plumbed through `EvalContext.withIteration`, which merges parent and child iteration vars. Storing the named loop var under its bare key piggybacks on the same mechanism. The `Reference` case in `evaluate` already routes through `_evalReference`; the only addition is the `iterationVars[name]` check before the statement-map lookup.
- **Streaming parser safety.** Mid-stream, the autoclose pass turns `@Each(rows, "t"` into a parseable `BuiltinCall` with 2 args. Without gating, validation would surface a `@Each requires 3 args` error on every keystroke. The `committedOffsetBoundary` parameter on `_validateEachShape` (see Proposed Solution step 4) skips statements whose offset is in the autoclose tail, which is the gate.
- **Name rule.** `[a-z_][a-zA-Z0-9_]*` mirrors the lexer's IDENT rule. Reject `true`/`false`/`null` explicitly. Empty string rejected. Strings starting with `$` rejected (would mask the STATEVAR convention — also implicitly blocks `$item` / `$index` to keep iteration vars distinct from reactive state). Case is lowercase-leading by intent — capitalized leading letters are reserved for component types.
- **Renderer.** `_renderIteration` and `_resolvePropValue` both special-case `@Each` and `@Map`. The change touches both. Verify the partial-render path (`Acceptance Gap A6`, in-flight statements) still no-ops correctly when `@Each` has 2 args mid-stream — it should, because `_renderIteration` already returns `null` on arity miss and `_wrapPrimitive(evaluate(...))` falls back to the evaluator (which now also returns `[]`).
- **Nested `@Each`.** `@Each(outer, "o", @Each(o.children, "c", row(o, c)))` should bind `o` in the outer scope and merge `{c: <inner>}` over it in the inner scope. `EvalContext.withIteration` spreads `parent.iterationVars` into the child map, so the outer `o` survives. Worth a dedicated test.
- **`$index` shadowing inside nested `@Each`.** Inner overwrites outer. Documented as a v0.1 limitation; a later 4-arg form `@Each(list, "name", "idx", tpl)` could add it non-breakingly.
- **JS reference parity.** Brainstorm flagged this as worth confirming before locking. Implementer should sanity-check the upstream JS shape during the first PR; if it differs, escalate before merging.
- **No demo scripts / no production callers** exercising the old 2-arg form. Search confirmed only `builtins_test.dart`, `parser_test.dart`, `materialize_test.dart`, and the renderer source.

## Acceptance Criteria

- [ ] `parseExpression('@Each(items, "t", t.name)')` returns a `BuiltinCall` with 3 args (name `Literal("t")`, template `MemberAccess(Reference("t"), "name")`).
- [ ] `parseProgram('root = @Each(items, $item)')` records a `ParseException` whose message points at the new 3-arg shape.
- [ ] `parseProgram('root = @Each(items, name, t.x)')` (name is a `Reference`, not a `Literal`) records a `ParseException`.
- [ ] `parseProgram('root = @Each(items, "true", t.x)')` records a `ParseException` (reserved name).
- [ ] `parseProgram('root = @Each(items, "", t.x)')` records a `ParseException` (empty name).
- [ ] `parseProgram('root = @Each(items, "$bad", t.x)')` records a `ParseException` (must match IDENT rule, no leading `$`).
- [ ] `parseProgram` `ParseException` messages for invalid `@Each` shapes contain the literal strings `"3 args"` and/or `"string identifier"` so the streaming filter and downstream tooling can rely on stable wording.
- [ ] Evaluating `@Each([1,2,3], "n", n + 10)` returns `[11, 12, 13]`.
- [ ] Evaluating `@Each(["a","b"], "n", $index)` returns `[0, 1]`.
- [ ] Evaluating `@Each([[1,2],[3]], "outer", @Each(outer, "inner", outer + inner))` returns `[[2, 3], [6]]` (or analogous nested case using member access on objects).
- [ ] Evaluating `@Each(items, item)` (2 args) emits an `EvaluationError` mentioning the new 3-arg shape and returns `[]`.
- [ ] Evaluating `@Each(null, "n", n)` returns `[]` with no error.
- [ ] Evaluating `@Each("hi", "n", n)` emits `@Each expects a list` and returns `[]`.
- [ ] Streaming parser fed `root = @Each(rows, "t"` (no closing paren, no third arg yet) yields a `ParseResult` whose `meta.errors` contains no `@Each` shape complaint. The `incomplete` set contains `root`.
- [ ] Streaming parser fed `root = @Each(rows, "t", Tag(t.name))\n` yields a `ParseResult` whose `meta.errors` is empty and whose `root` materializes.
- [ ] Renderer test (`packages/openui/test/src/renderer_test.dart`): a list-of-widgets `@Each` template with the new 3-arg form renders one widget per item, with the named loop var visible in props.
- [ ] Renderer prop-branch test: a component prop set to `@Each(items, "row", Card(title: row.name))` resolves through `_resolvePropValue`'s widget-iteration branch and renders one card per item.
- [ ] `packages/openui_core/test/src/parser/materialize_test.dart` line 280 case updated to the 3-arg form and still passes reachability assertion.
- [ ] `docs/lang-reference.md` reflects the new signature.
- [ ] `packages/openui_core/CHANGELOG.md` documents the breaking change.
- [ ] `packages/openui/CHANGELOG.md` notes the renderer-iteration arg-index change under the unreleased section.
- [ ] System prompt grammar primer mentions the new shape in one line.
- [ ] JS reference parity confirmed: implementer reads the upstream JS `@Each` signature shape and notes the comparison in the PR description before merging. If JS differs from `@Each(list, "name", template)`, escalate before locking.
- [ ] `@Map` and `@Filter` tests pass unchanged (regression check).
- [ ] Full test suite passes: `flutter test` in `packages/openui_core` and `packages/openui`.
- [ ] `very_good_analysis` passes; `flutter analyze` clean.

## Success Metrics

- One signature for `@Each` in the spec, parser, evaluator, and renderer.
- Streaming UX unaffected (no false errors on partial `@Each`).
- Existing `@Map`/`@Filter` behavior unchanged (no test diffs in those groups).
- Single migration commit; `builtins_test.dart` `@Each` group rewritten; `parser_test.dart` and `streaming_test.dart` gain shape-validation coverage.

## Dependencies & Risks

- **Risk: streaming false-positives.** If the offset filter is wrong (e.g., off-by-one against `split.prefix.length`), the UX regresses. Mitigation: dedicated streaming test for mid-stream `@Each` shapes.
- **Risk: evaluator-only validation accidentally hides parser regressions.** Mitigation: parser test asserts `Program.errors` is non-empty on each invalid shape, separately from the evaluator tests.
- **Risk: JS reference parity drift.** Brainstorm-flagged open question. Implementer must confirm the upstream JS `@Each` signature before merging. If JS uses a different shape, this plan is wrong — escalate.
- **Risk: missed renderer call sites.** Renderer has two `@Each`-aware paths (`_renderIteration`, `_resolvePropValue`). Grep `_isIterating` and `call.name == '@Each'` to confirm full coverage.
- **No dependency-version bumps required.** Pure source change inside the monorepo.

## References & Research

- Brainstorm: `docs/brainstorm/2026-05-14-each-named-loop-var-brainstorm-doc.md`
- Existing evaluator: `packages/openui_core/lib/src/eval/evaluator.dart:178` (`_evalReference`), `:196` (`_evalStateRef`), `:87` (`withIteration`)
- Existing builtin: `packages/openui_core/lib/src/eval/builtins.dart:88` (`_evalEach`), `:94` (`_iterate`)
- Parser: `packages/openui_core/lib/src/parser/parser.dart:73` (`parseProgram`), expressions primary at `packages/openui_core/lib/src/parser/expressions.dart:128`
- Streaming compute: `packages/openui_core/lib/src/parser/streaming.dart:191` (`_compute`), incomplete logic at `:202`
- Renderer iteration: `packages/openui/lib/src/renderer.dart:457` (`_renderIteration`), `:552` (`_resolvePropValue` widget branch), `:568` (`_isIterating`)
- Existing test patterns: `packages/openui_core/test/src/eval/builtins_test.dart:182` (`@Each` group), `:290` (nested iteration scope), parser tests at `packages/openui_core/test/src/parser/parser_test.dart:619`
- Recent breaking-change precedent: commit `d5c5941` (`feat(openui_core)!: array-only x-action plans`) — same shape of breaking-change + CHANGELOG + test rewrite.
- Lang reference row to edit: `docs/lang-reference.md:87`
