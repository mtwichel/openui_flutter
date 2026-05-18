## 0.1.0

- **BREAKING**: `Query(name: ..., args: ...)` is removed. Use the new
  `@Query` builtin as the entire RHS of a `$var =` assignment:
  `$products = @Query(fetch_products, category: "shoes")`. The slot is
  `null` until the tool resolves; re-fire with `@Run($products)`. The
  parser rejects the old form with a migration `ParseException`. The
  `QueryCall` AST class and `EvalContext.queryResults` are removed.
  `QueryDecl` now carries `toolName` + `namedArgs` (the legacy
  `List<Argument> args` field is gone). The `@Run` action step accepts
  a `StateRef` first arg so `@Run($var)` re-fires the bound query.
- **BREAKING**: `@Each` now takes three args — `@Each(list, "name", template)`.
  The loop variable is named explicitly via a string literal and bound under
  its bare key inside the template (e.g. `@Each(items, "row", Card(title:
  row.name))`). `$index` is still bound. The 2-arg implicit-`$item` form is
  removed. `@Map` and `@Filter` are unchanged. `parseProgram` records a
  `ParseException` for shape-invalid `@Each` calls (wrong arity,
  non-string-literal name, reserved name, empty name, leading `$`).

### Phase 1 — `openui_core` language and runtime

The language core ships in 13 milestones built on top of the Phase 0
walking-skeleton lexer. All public symbols carry `@experimental` per
Decision D12.

- **feat**: walking-skeleton lexer covering the OpenUI Lang token set
  (identifier, type, statevar, builtin sigil, string, number,
  operator, punct, newline, EOF). Recoverable mode tolerates partial
  tail tokens; eager mode throws `LexException`.
- **feat**: OpenUI Lang Pratt parser. Sealed `AstNode` hierarchy
  (`Literal`, `NullLiteral`, `Reference`, `StateRef`, `StateAssign`,
  `ArrayLit`, `ObjectLit`, `BinaryOp`, `UnaryOp`, `Ternary`,
  `MemberAccess`, `IndexAccess`, `CompCall`, `BuiltinCall`,
  `QueryCall`, `MutationCall`); `Statement` + `StatementKind` +
  `classifyStatement`; `parseProgram(source, {recoverable})`,
  `parseExpression(source)`, `autoClose(text)`.
- **feat**: streaming parser. `createStreamingParser({rootName})`
  returns a `StreamParser` with `push(chunk)` / `set(fullText)`;
  splits buffer at last bracket-depth-zero newline, runs `autoClose`
  on the pending tail, re-parses in recoverable mode. Returns
  `ParseResult` with `statements`, materialized `root`, and
  `ParseMeta` (`incomplete`, `unresolved`, `orphaned`, `errors`,
  `stateDecls`, `queries`, `mutations`).
- **feat**: materializer. `materialize(rootName, statements,
  {incomplete})` does graph-shaped reachability — BFS over the
  statement-id map, partitions into reachable / unresolved /
  orphaned. State, query, and mutation declarations are excluded
  from orphan analysis. Lightweight `ElementNode` carries the
  unevaluated root RHS plus `partial` flag.
- **feat**: reactive `Store`. Pure-Dart key/value bag with shallow
  equality short-circuit on `set`, listener subscribe/unsubscribe,
  unmodifiable `getSnapshot()`, and `initialize(defaults,
  [persisted])` that never overwrites user-modified bindings. Per
  Decision D4, one `Store` per `Renderer`.
- **feat**: sealed `OpenUIError` hierarchy. `ParseError`,
  `EvaluationError`, `CyclicStateError`, `UnknownComponentError`,
  `McpToolError`, `ToolNotFoundError`, `AdapterMismatchError`. Each
  carries a stable machine-readable `code`, optional `message` /
  `hint` / `statementId`, and structural equality so dedup over
  `Renderer.onError` lists reduces to `listEquals`.
- **feat**: AST evaluator. `evaluate(AstNode, EvalContext) →
  Object?` walks every concrete AST case (literals, references with
  cycle detection, state refs / assigns, array / object literals,
  binary and unary operators, ternary, member access, index access).
  `BuiltinCall` dispatches through `EvalContext.builtins`; comp,
  query, and mutation calls in expression position are category
  errors. `withIteration(...)` produces a child context that shares
  errors and cycle state.
- **feat**: functional builtins. `functionalBuiltins` registry
  drops `@Count`, `@Filter`, `@Each`, `@Map` straight into
  `EvalContext.builtins`. `$item` and `$index` are pushed through
  `withIteration` per element; predicates and templates can be
  inline expressions or `Reference`s.
- **feat**: action steps and dispatcher. Sealed `ActionStep`
  variants (`SetStep`, `ResetStep`, `RunStep`,
  `ContinueConversationStep`, `OpenUrlStep`), `ActionPlan` wrapper,
  `actionPlanFromAst(AstNode)` bridge, and `dispatchAction(...)` that
  re-evaluates `valueAst` at click time per Decision D3. `RunStep`
  failures halt the rest of the plan.
- **breaking (experimental)**: `actionPlanFromAst` accepts only a
  non-empty array literal whose elements are all valid `@Set` /
  `@Reset` / `@Run` / `@ToAssistant` calls (strict: no bare builtins,
  no `Action(...)` wrapper, no empty `[]`, no mixed non-action
  elements). Other shapes yield `null`.
- **feat**: `mergeStatements(existing, patch, {rootId})` for the
  LLM "edit, don't rewrite" pathway. Strips Markdown fences, applies
  upserts and `NullLiteral` deletes, runs the materializer's orphan
  GC to drop unreachable value statements, re-emits with per-statement
  whitespace preserved.
- **feat**: `ToolProvider` interface, `ToolResult` envelope, and
  `extractToolResult` helper. Mirrors spike S0.3 — `isError` throws
  `McpToolError`, structured content wins over text, JSON-shaped text
  is decoded, otherwise the raw string. No `mcp_dart` dependency in
  core.
- **feat**: `Library<W>` registry, `Component<W>`,
  `defineComponent<W>(...)`, `reactive(Schema)` wrapper, and the
  `ReactiveAssign` marker + `isReactiveAssign` helper. `Schema` is
  re-exported from `json_schema_builder`; the `x-reactive` extension
  keyword survives `toJson()` per spike S0.1.
- **feat**: `evaluateElementProps(call, schema, context)` — walks a
  `CompCall`'s named args, emits `ReactiveAssign` markers for
  reactive props bound to a bare `$state` ref, evaluates the rest
  normally. Bridges the parser-side AST to the renderer-side prop
  contract.
- **feat**: `parse(source, paramMap, {rootName})` integration
  entry. Builds a fully-resolved `ResolvedElement` tree in one pass:
  ref resolution with cycle detection, positional → named prop
  mapping, required-prop validation (`missing-required` /
  `null-required`), `excess-args` detection, `UnknownComponentError`
  for components not in the `ParamMap`, array null-dropping for
  invalid children, orphan tracking, and `$state` auto-declaration.
  Ports the JS reference's `parser.test.ts` contract suite verbatim.
