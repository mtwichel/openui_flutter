# openui

[![Pub](https://img.shields.io/pub/v/openui.svg)](https://pub.dev/packages/openui)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Flutter `Renderer` widget for OpenUI Lang.

The renderer takes a streaming `response: String` from your LLM, parses it
against a `Library` of components, and rebuilds the widget tree on every
chunk. It owns the reactive store, the form-state cache (so
`TextEditingController`s survive mid-stream rebuilds), and the
streaming-tolerant error boundary.

## Status

v0.1, Phase 2 — not started. The Phase 0 scaffold is in place; the
`Renderer` widget lands here.

## Phase 2 plan

Full scope is in
[`docs/plan/2026-05-10-feat-openui-flutter-port-plan.md`](../../docs/plan/2026-05-10-feat-openui-flutter-port-plan.md)
(`#### Phase 2: openui renderer`). Deliverables:

1. **`Renderer` widget** (`lib/src/renderer.dart`) — `StatefulWidget` with
   the API table below. Owns parser, store, query manager, form-state
   cache, error boundary.
2. **`_FormStateCache`** (`lib/src/form_state_cache.dart`) — keyed by
   `(formName, fieldName)`, 250 ms debounce before disposal (Decision D7).
3. **`_ErrorBoundary` widget** (`lib/src/error_boundary.dart`) — wraps
   every component render; caches last successful child; recovers on the
   next non-throwing `build()`.
4. **Component dispatch** (`lib/src/render_node.dart`) — looks up
   `Component<Widget>` by `typeName` in the library, invokes
   `ComponentRender<Widget>(context, props, renderNode, statementId)`.
5. **`renderNode` callback** — recursive child rendering. Reactive props
   arrive as `ReactiveAssign` markers (use `isReactiveAssign` from core).
6. **Loading overlay** — 0.7 opacity + 0.2 s transition while a query is
   loading; honors the optional `queryLoadingPlaceholder` slot.
7. **Streaming UX** — interactive components disable tap targets when
   their containing statement is `meta.incomplete` (Acceptance Gap A6).
8. **MCP detection** — `Renderer` checks if `toolProvider` is an MCP
   adapter and runs `extractToolResult` on its responses.
9. **Error deduplication** — `onError` fires only when the error set
   changes (`listEquals` over `OpenUIError`'s structural equality).
   Errors clear during streaming for LLM correction loops.
10. **Widget tests** — cold render, streaming append (focus preserved),
    error boundary recovery, form controller persistence across rebuild,
    reactive prop two-way binding, action dispatch (set, reset, run,
    continue_conversation, open_url).

Success criteria: 100% line coverage on logic, widget tests demonstrate
focus preservation across mid-stream rebuilds, error boundary recovers
cleanly, every public symbol has dartdoc.

## What `openui_core` provides for Phase 2

The renderer composes existing pieces from `openui_core`:

| Use this | For |
|---|---|
| `createStreamingParser(rootName: ...)` | Per-chunk parse + materialization. Returns `ParseResult` with `root: ElementNode?`, `meta` (incomplete / unresolved / orphaned / errors / stateDecls / queries / mutations). |
| `parse(source, paramMap, {rootName})` | Optional integration entry that mirrors the JS reference — returns `CompiledProgram` with a fully-resolved `ResolvedElement` tree (`typeName + props + statementId`). Useful for non-streaming render passes and the contract suite. |
| `Library<Widget>` | Component registry. Each `Component<Widget>` carries a `Schema` and a `ComponentRender<Widget>` callback. `defineComponent<Widget>(...)` is the factory. |
| `evaluateElementProps(call, schema, context)` | Walks a `CompCall`'s named args, evaluates them against the `EvalContext`, emits `ReactiveAssign` markers for reactive props bound to `$state`. |
| `Store` | One per `Renderer` (Decision D4). `set` short-circuits on shallow equality. `subscribe(...)` returns the unsubscribe callback. |
| `EvalContext` | Statements, store, query results, iteration scope, builtins, errors sink. `withIteration({...})` shares the cycle-detection set across children. |
| `evaluate(ast, context)` | Runtime AST → value. Used by component renderers that need to resolve sub-expressions dynamically (e.g. dynamic styles). |
| `functionalBuiltins` | Drop into `EvalContext.builtins` to get `@Count`, `@Filter`, `@Each`, `@Map`. |
| `actionPlanFromAst(astNode)` → `dispatchAction(plan: ..., context: ..., onRun: ..., onContinueConversation: ..., onOpenUrl: ..., stateDefaults: ...)` | Bridge from action-shaped AST to plan execution. `SetStep.valueAst` re-evaluates against the live store at click time per Decision D3. |
| `mergeStatements(existing, patch, {rootId})` | LLM "edit, don't rewrite" pathway. The renderer never invokes this automatically (Acceptance Gap A17). |
| `ToolProvider` + `extractToolResult` | Query / mutation execution. `openui_mcp` will implement `ToolProvider` over `mcp_dart`; the renderer wraps the call site so any provider works. |
| `OpenUIError` hierarchy | Sealed: `ParseError`, `EvaluationError`, `CyclicStateError`, `UnknownComponentError`, `McpToolError`, `ToolNotFoundError`, `AdapterMismatchError`. Each has structural equality so dedup is a `listEquals` over the error list. |

Open question for Phase 2: should `Renderer` use `createStreamingParser` +
runtime `evaluate` per render, or the static `parse(source, paramMap)` +
treewalker? The plan says streaming parser. The `parse()` integration
gives an easier mental model but doesn't yet have a streaming variant.

## `Renderer` API (from the plan)

```dart
class Renderer extends StatefulWidget {
  final String? response;
  final Library<Widget> library;
  final bool isStreaming;
  final void Function(ActionEvent)? onAction;
  final void Function(Map<String, Object?>)? onStateUpdate;
  final Map<String, Object?>? initialState;
  final void Function(ParseResult?)? onParseResult;
  final ToolProvider? toolProvider;
  final QueryLoader? queryLoader;
  final void Function(List<OpenUIError>)? onError;
  final Widget? queryLoadingPlaceholder;
}
```

`ActionEvent` and `QueryLoader` are new types that land with the renderer.
`Library` is `openui_core`'s generic `Library<W>` pinned to `Widget`.

## Decisions to honor

Read these before writing the renderer:

- [`D3` Action `$var` resolution](../../docs/decisions/2026-05-10-phase0-decisions.md) — at dispatch (click) time, against current store. `dispatchAction` already implements this.
- [`D4` Reactive store scope](../../docs/decisions/2026-05-10-phase0-decisions.md) — one `Store` per `Renderer`.
- [`D7` Form controller cache](../../docs/decisions/2026-05-10-phase0-decisions.md) — per-`Renderer`, keyed by `(formName, fieldName)`, 250 ms grace before disposal.
- [`D8` Concurrent renders / sends](../../docs/decisions/2026-05-10-phase0-decisions.md) — queue-and-replace.

## Install

```yaml
dependencies:
  openui: ^0.1.0
```

## License

MIT — see [LICENSE](LICENSE).
