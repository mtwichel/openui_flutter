# openui_core

[![Pub](https://img.shields.io/pub/v/openui_core.svg)](https://pub.dev/packages/openui_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Pure-Dart language core for the [OpenUI Flutter](../../README.md) port. Lexer,
parser, evaluator, reactive store, library DSL, action dispatcher, tool-provider
interface, and JS-compatible integration entry — everything OpenUI Lang needs
that does not touch Flutter.

Runs in any Dart context — a Flutter app, a server, a Cloudflare Worker, a
CLI. The `openui` (Flutter) and `openui_components` packages sit on top.

## Install

```yaml
dependencies:
  openui_core: ^0.1.0
```

## Status

v0.1 is in active development. Phase 1 is complete: 461 tests, 100% line
coverage across 16 source files. All public symbols carry `@experimental` per
Decision D12.

## Public API

The barrel `lib/openui_core.dart` is the only file consumers should import.
Everything under `lib/src/**` is private.

### Parser

```dart
final program = parseProgram(source, recoverable: true);
final expr = parseExpression(source);
final closed = autoClose(partialSource);
```

Sealed `AstNode` hierarchy (`Literal`, `Reference`, `StateRef`, `StateAssign`,
`ArrayLit`, `ObjectLit`, `BinaryOp`, `UnaryOp`, `Ternary`, `MemberAccess`,
`IndexAccess`, `CompCall`, `BuiltinCall`, `QueryCall`, `MutationCall`,
`NullLiteral`) plus `Statement` / `StatementKind` and `classifyStatement`.

### Streaming parser

```dart
final parser = createStreamingParser(rootName: 'root');
final result = parser.push('root = Stack([\n  Card()\n');
// `result.meta.incomplete` flags in-flight statements;
// `meta.unresolved` lists unbound references;
// `meta.orphaned` lists unreachable value statements;
// `meta.stateDecls` / `meta.queries` / `meta.mutations` carry
// declarations; `result.root` is the materialized entry point.
```

### Materializer

```dart
final res = materialize(
  rootName: 'root',
  statements: program.statements,
  incomplete: const {'root'},
);
res.root;        // ElementNode? at the entry point
res.unresolved;  // List<String>
res.orphaned;    // List<String>
```

### Integration entry — `parse(source, paramMap)`

Mirrors the JS reference's `parse(input, cat, rootName?)`. Builds a fully-
resolved `ResolvedElement` tree in one pass, including required-prop
validation and `UnknownComponentError` reporting.

```dart
final paramMap = <String, List<ParamSpec>>{
  'Stack': [const ParamSpec(name: 'children', required: true)],
  'Title': [const ParamSpec(name: 'text', required: true)],
};

final result = parse('root = Stack([Title("hi")])', paramMap);
result.root!.typeName;             // 'Stack'
result.root!.props['children'];    // List<ResolvedElement>
result.meta.errors;                // List<OpenUIError>
result.meta.unresolved;            // List<String>
result.stateDeclarations;          // auto-declared $vars
```

### Reactive store

```dart
final store = Store()
  ..initialize({r'$count': 0})  // does not overwrite user-modified keys
  ..set(r'$count', 1);          // shallow-equality short-circuits no-op writes
final unsubscribe = store.subscribe(() => print('changed'));
store.dispose();                 // listeners cleared; further ops throw
```

### Evaluator

```dart
final ctx = EvalContext(
  statements: program.statements,
  store: Store()..set(r'$count', 3),
  builtins: functionalBuiltins,    // @Count, @Filter, @Each, @Map
);
evaluate(ast, ctx);                // Object?
ctx.errors;                        // CyclicStateError + EvaluationError
```

### Action plan + dispatcher

```dart
final plan = actionPlanFromAst(rhs)!;  // null if rhs isn't an action AST
await dispatchAction(
  plan: plan,
  context: ctx,
  stateDefaults: const {r'$count': Literal(0, offset: 0)},
  onRun: (id) async => queryManager.refresh(id),
  onOpenUrl: (url) => launchUrl(url),
  onContinueConversation: (msg, extraCtx) => controller.send(msg),
);
```

`SetStep.valueAst` is re-evaluated against the current store at click time
(Decision D3).

### `mergeStatements`

```dart
final merged = mergeStatements(
  existing,
  patch,           // an LLM-emitted edit set
  rootId: 'root',
);
```

Strips Markdown fences, upserts patches, deletes `NullLiteral` statements,
runs the orphan GC, re-emits with per-statement whitespace preserved.

### Library and `defineComponent`

```dart
final lib = Library<MyWidget>([
  defineComponent<MyWidget>(
    name: 'Input',
    schema: Schema.object(properties: {
      'value': reactive(Schema.string()),  // marks as two-way bound
      'placeholder': Schema.string(),
    }),
    render: (ctx, props, renderNode, statementId) => MyWidget.input(props),
  ),
]);

final props = evaluateElementProps(
  call: compCall,
  schema: lib['Input']!.schema,
  context: ctx,
);
// Reactive props bound to `$state` arrive as `ReactiveAssign(target, value)`
// markers; check via `isReactiveAssign(value)`.
```

### Tool provider

```dart
class MyProvider implements ToolProvider {
  @override
  Future<Object?> callTool(String name, Map<String, Object?> args) async {
    final raw = await transport.call(name, args);
    return extractToolResult(
      ToolResult(text: raw.body, isError: raw.statusCode >= 400),
    );
  }
}
```

### Error vocabulary

`OpenUIError` is sealed. Subclasses: `ParseError`, `EvaluationError`,
`CyclicStateError`, `UnknownComponentError`, `McpToolError`,
`ToolNotFoundError`, `AdapterMismatchError`. Each carries `code`, optional
`message` / `hint` / `statementId`, and structural equality.

## Layout

```
lib/src/
├── parser/    lexer, AST, parser, statements, streaming, materialize
├── parse/     integration entry, ResolvedElement, ParamMap
├── state/     reactive Store
├── eval/      evaluator + functional builtins
├── library/   Component, Library, reactive, evaluateElementProps
├── actions/   ActionStep, ActionPlan, dispatcher
├── merge/     mergeStatements
├── errors/    sealed OpenUIError hierarchy
└── tools/     ToolProvider, ToolResult, extractToolResult
```

See [`docs/lang-reference.md`](../../docs/lang-reference.md) for the language
grammar and [`docs/architecture.md`](../../docs/architecture.md) for the
package map and data flow.

## License

MIT — see [LICENSE](LICENSE).
