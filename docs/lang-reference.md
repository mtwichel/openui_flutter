# OpenUI Lang reference (Dart port)

This is the canonical Dart-side reference for the OpenUI Lang grammar and semantics. It is faithful to the JS reference at [thesysdev/openui](https://github.com/thesysdev/openui) plus the [OpenUI Lang specification](https://www.openui.com/docs/openui-lang/specification-v05). Where the Dart port deviates, the section is marked **Dart note**.

## Lexical structure

Tokens:

| Token | Pattern |
|---|---|
| `IDENT` | `[a-z_][a-zA-Z0-9_]*` |
| `TYPE` | `[A-Z][a-zA-Z0-9_]*` (capitalized identifiers — component names) |
| `STATEVAR` | `\$[a-zA-Z_][a-zA-Z0-9_]*` |
| `BUILTIN` | `@[a-zA-Z_][a-zA-Z0-9_]*` (builtin sigil — `@Each`, `@Set`, ...) |
| `NUMBER` | integer or decimal, no scientific notation |
| `STRING` | double-quoted, supports `\"`, `\\`, `\n`, `\t`, `\r` |
| `KEYWORD` | reserved word: `true`, `false`, `null` |
| `OPERATOR` | `+ - * / % == != < > <= >= && \|\| !` |
| `PUNCT` | `( ) [ ] { } , . ? : =` |
| `NEWLINE` | `\n` (or end of input) |
| `EOF` | end of input |

Whitespace within a line is insignificant. Comments are not part of v0.1.

## Grammar

```ebnf
program       ::= statement* EOF
statement     ::= identifier "=" expression NEWLINE
identifier    ::= IDENT | TYPE | STATEVAR
expression    ::= comp_call | builtin_call | ternary | binary_op | unary_op
                | member_access | index_access | state_assign | literal
                | array | object | reference

comp_call     ::= TYPE "(" arg_list ")"
builtin_call  ::= "@" IDENT "(" arg_list ")"
state_assign  ::= "$" IDENT "=" expression
state_ref     ::= "$" IDENT

ternary       ::= expression "?" expression ":" expression
binary_op     ::= expression OPERATOR expression
unary_op      ::= ("!" | "-") expression
member_access ::= expression "." IDENT
index_access  ::= expression "[" expression "]"

literal       ::= STRING | NUMBER | "true" | "false" | "null"
array         ::= "[" (expression ("," expression)*)? "]"
object        ::= "{" (object_pair ("," object_pair)*)? "}"
object_pair   ::= (IDENT | STRING) ":" expression
reference     ::= IDENT
arg_list      ::= (arg ("," arg)*)?
arg           ::= expression | named_arg
named_arg     ::= IDENT ":" expression
```

Operator precedence (highest to lowest):

1. Member/index access (`.`, `[]`)
2. Unary `!`, unary `-`
3. `*`, `/`, `%`
4. `+`, `-`
5. `<`, `<=`, `>`, `>=`
6. `==`, `!=`
7. `&&`
8. `||`
9. Ternary `? :` (right-associative)

## Statement classification

Every statement is classified at parse time as one of:

| Kind | Trigger | Example |
|---|---|---|
| `value` | RHS is a literal, reference, member access, or comp call without state semantics | `greeting = "Hello"` |
| `state` | LHS is a `$IDENT` and RHS is not a `Query` / `Mutation` builtin | `$count = 0` |
| `query` | RHS is `Query(...)` or LHS is a `$IDENT` whose RHS is `Query(...)` | `users = Query(name: "list_users")` |
| `mutation` | RHS is `Mutation(...)` | `delete_user = Mutation(name: "delete", args: { id: 1 })` |

**Order of checks matters.** `query` is checked before `state`, because `$foo = Query(...)` must classify as a query. `mutation` is checked before `query` only when the RHS shape is unambiguous.

## Builtins

| Builtin | Signature | Semantics |
|---|---|---|
| `@Count` | `@Count(list)` | Returns `list.length` (or `0` if the input is null) |
| `@Filter` | `@Filter(list, predicateRef)` | Filters `list` by calling the predicate (a comp ref) on each item |
| `@Each` | `@Each(list, itemTemplate)` | Materializes `itemTemplate` once per item, substituting `$item` and `$index` references. Lazy: not evaluated until needed |
| `@Map` | `@Map(list, transformRef)` | Maps each element through a comp ref |

Action-step builtins (only as elements of a **non-empty array literal** on props marked `x-action: true` in the component schema, for example `onClick: [@Set($count, $count + 1)]` or `onClick: [@Run(refresh), @Set($flag, 1)]`. Bare `@Step(...)`, empty `[]`, `Action(...)`, and arrays containing non-action expressions are rejected.)

| Builtin | Signature | Semantics |
|---|---|---|
| `@Set` | `@Set(target, value)` | Re-evaluate `value` at click time against the current store, then `store.set(target, evaluated)` |
| `@Reset` | `@Reset(target1, target2, ...)` | Reset each target to its declared default |
| `@Run` | `@Run(statementId)` | Re-fire a query or mutation by statement id |
| `@ToAssistant` | `@ToAssistant(message, context?)` | Enqueue a user message in the chat controller |

The action plan dispatcher executes steps sequentially. `@Run` returning an error halts the plan unless a `catch` field is provided (deferred to v0.2).

## Reactive props

Components declare their props via `defineComponent(name, schema, render)`. To mark a prop as reactive (two-way bound to a `$state` variable), wrap its schema in `reactive(...)`:

```dart
defineComponent(
  'Input',
  schema: S.object({
    'value': reactive(S.string()),
    'placeholder': S.string().optional(),
  }),
  render: (context, props, renderNode, statementId) => ...,
);
```

When the evaluator encounters a reactive prop whose value resolves to a `$varName` reference, it does not resolve the value. Instead it emits a `ReactiveAssign(target: '$varName', value: <currentValue>)` marker. The component receives the marker via `props['value']`; it calls `isReactiveAssign(value)` and, if true, sets up two-way binding to `store`.

## Action timing

`[@Set($count, $count + 1)]` (and each step in a multi-step plan) resolves values **at click time**, against the current store. Per Decision D3, `SetStep.valueAst` is an `AstNode`, not a pre-evaluated `Object?`. The dispatcher loop evaluates each step's AST against the *current* store at the moment the dispatcher reaches it — long-running `@Run` steps preceding a `@Set` see the freshest state.

Pseudocode:

```dart
for (final step in plan.steps) {
  switch (step) {
    case SetStep(:final target, :final valueAst):
      final value = evaluator.evaluate(valueAst, currentContext);
      store.set(target, value);
    case ResetStep(:final targets):
      for (final t in targets) store.set(t, store.defaultFor(t));
    case RunStep(:final statementId):
      await queryManager.fire(statementId);
    case ContinueConversationStep(:final messageAst, :final contextAst):
      onHostStep(ActionEvent(
        type: BuiltinActionType.continueConversation,
        humanFriendlyMessage: evaluate(messageAst),
        params: contextAst == null ? {} : {'context': evaluate(contextAst)},
      ));
  }
}
```

The host subscribes to `Renderer.onAction`, which fires once per
host-routed step (including `@Set`, `@Reset`, and `@Run` outcomes in the current Dart implementation).

## Streaming semantics

The streaming parser exposes:

- `push(String chunk) → ParseResult` — append chunk, return latest parse
- `set(String fullText) → ParseResult` — replace buffer, diff against prior, return latest parse

`ParseResult` carries:

- `root: ElementNode?` — the materialized tree, rooted at `rootName` (default `'root'`)
- `meta.incomplete: List<String>` — statement ids whose source was truncated
- `meta.unresolved: List<String>` — references that could not be resolved
- `meta.orphaned: List<String>` — statements not reachable from `root`
- `meta.errors: List<OpenUIError>` — parse and evaluation errors
- `meta.stateDecls: List<StateDecl>` — `$state` declarations with their default values
- `meta.queries: List<QueryDecl>` — query declarations with name and args
- `meta.mutations: List<MutationDecl>` — mutation declarations

Forward references are allowed: `root = Stack([chart])` may appear before `chart = ...`. Unresolved references at the end of input land in `meta.unresolved` and the rendered tree shows nothing for them.

`autoClose(text)` is the partial-recovery pass. It scans for unmatched `"` / `[` / `(` / `{` and inserts the missing closer. The pass runs only on the pending tail (after the last bracket-depth-zero newline), so completed statements are unaffected.

**Dart note.** The JS reference uses Web `ReadableStream` for input. The Dart port is transport-agnostic: `push(String)` works in any context. If you consume SSE, decode bytes with `Utf8Decoder(allowMalformed: true)` before chunk framing so malformed code units do not tear down the stream.

## Cyclic state

Per Decision D15, the evaluator carries a per-evaluation `Set<String>` of `$var`s currently being resolved. Re-entering the set yields `null` and emits `meta.errors.add(CyclicStateError(...))`. `a = $b\nb = $a` is data, not a process crash.

## Library and `defineComponent`

A `Library` is a compiled bag of component definitions. Each definition is a `(name, schema, render)` triple. `Library.id` is a stable hash over the registered names plus their schema fingerprints — two libraries with the same components are `==`. Schema-tagging uses `Expando<String>` (Dart's `WeakMap` analogue): the schema's compiled `ParamMap` is attached to the schema instance for O(1) prop mapping at render time.

```dart
final lib = createLibrary(components: [
  defineComponent('Stack', schema: stackSchema, render: stackRender),
  defineComponent('Card', schema: cardSchema, render: cardRender),
  // ...
]);
```

`openui_components` ships two ready-made libraries:

- `openuiLibrary()` — no root wrapper
- `openuiChatLibrary()` — wraps every response in a `Card`, matching the JS `genui-chat-lib`

## `mergeStatements` (edit mode)

Port of JS `mergeStatements(existing, patch, rootId = 'root')`:

1. Parse both inputs (treat `patch` as preprocessed; strip code fences first).
2. If `existing` is empty, return `patch.raw.join('\n')`.
3. If `patch` is empty, return `existing` unchanged.
4. Build `Map<id, raw>`, `Map<id, ast>`, ordered `List<id>` from existing.
5. For each patch statement: if `ast` is a `NullLiteral`, delete; otherwise upsert (overwrite raw and ast) and append-if-new to the order.
6. Run `_gcUnreachable(order, merged, asts, rootId)` to drop orphans.
7. Return `order.where((id) => merged.containsKey(id)).map((id) => merged[id]).join('\n')`.

This is the LLM "edit, don't rewrite" pathway; the renderer never invokes it automatically (Acceptance Gap A17).

## Error vocabulary

| Error | When |
|---|---|
| `OpenUIError` | Base class; carries `code`, `hint`, `statementId?` |
| `ParseError` | Lexer or parser failure on a *completed* statement (the autoclose pass swallows partial-tail errors) |
| `EvaluationError` | Evaluator hit an unresolvable expression (member access on null, etc.) |
| `CyclicStateError` | Reactive-state cycle detected |
| `UnknownComponentError` | RHS comp name not in library |
| `McpToolError` | MCP `CallToolResult.isError == true` |
| `ToolNotFoundError` | `toolProvider.callTool(name)` for an unknown tool |
| `AdapterMismatchError` | Stream adapter encountered a malformed event |

All errors are surfaced via `meta.errors` (parse-time and eval-time) or `Renderer.onError` (render-time and adapter-time) — never thrown out of the renderer.

## Out of scope for v0.1

- Comments
- Function definitions (only `defineComponent` is exposed)
- Imports / namespaces
- Type annotations beyond what `defineComponent` schemas express
- `langgraph` and `openai-readable-stream` adapters (Acceptance Gap A21)
- Multi-thread chat state (Acceptance Gap A12)
- Persistence (Acceptance Gap A13)
