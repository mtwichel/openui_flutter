---
date: 2026-05-21
topic: separate-library-definitions-from-renderers
---

# Separate library definitions from render/execute behavior

## What We're Building

A foundational refactor that splits OpenUI's component and tool **definitions**
(name, description, input/output schemas, internal flag) from their **behavior**
(how components render to Flutter widgets, how tools execute). Today
`Component<W>` and `Library<W>` in `openui_core` bundle schema metadata with a
render callback in one generic type. After this change:

- **`openui_core`** holds pure-Dart, JSON-serializable **definition models**
  (`ComponentDefinition`, `ToolDefinition`, `LibraryDefinition`) built with
  `dart_mappable`. No generics. No render or execute callbacks. Schemas remain
  `json_schema_builder` `Schema` objects (serialized via existing to/from map).
- **`openui`** owns all Flutter-specific behavior: `ComponentRender` hardcoded
  to `Widget`, plus `ComponentRegistry` and `ToolRegistry` classes that wrap
  lookup maps (`componentName → render fn`, `toolName → execute fn`).
- **`openui_components`** exports both a standard `LibraryDefinition` and the
  matching component render map (and any built-in tool executors, if applicable).
- **`Renderer`** accepts a `LibraryDefinition` plus registries instead of a
  monolithic `Library<Widget>`.

Libraries are authored **code-first** (e.g. `standardLibraryDefinition().extend(...)`)
and serializable for prompt generation and future export — not loaded from JSON
files at runtime in v1.

This is a **clean break**: remove `Component<W>`, `Library<W>`, and `ComponentRender<W>`
entirely. Pre-1.0 breaking changes are acceptable.

## Why This Approach

Three approaches were considered:

**Approach A — Strict split (chosen)**

Core definition models + Flutter registries + explicit wiring on `Renderer`.

- Pros: clearest boundary between "what the LLM knows" and "what the app
  does"; core stays Flutter-free; registries can validate completeness
  (definition without renderer → clear error); mirrors how MCP already separates
  tool metadata from transport.
- Cons: apps must wire three objects (library, component registry, tool
  registry) unless helper bundles are provided.
- Best when: this is a foundational refactor serving multiple goals at once.

**Approach B — Strict split + bundled helpers**

Same as A, but `openui_components` exports a convenience bundle for the common
case (e.g. `standardOpenUI()` returning definition + registries together).

- Pros: easier migration from today's `standardLibrary()`.
- Cons: extra API surface; bundle could blur the separation we're trying to
  establish.
- Best when: ergonomics trump purity. Deferred — can add helpers after the
  strict split lands without changing the core model.

**Approach C — Registry-centric (definitions derived from registries)**

Registries hold both maps and definitions; `LibraryDefinition` is derived for
prompt generation only.

- Pros: single object to pass around.
- Cons: inverts the desired dependency direction (metadata becomes an
  implementation detail of rendering); harder to serialize/share definitions
  independently; server-side prompt generation would need the registry.
- Best when: developer ergonomics is the only goal. Rejected.

**Picked Approach A** — strict split with registry classes, matching the user's
preference and the existing layered architecture (`openui_core` pure Dart,
`openui` Flutter boundary).

## Key Decisions

- **Motivation is foundational, not single-use.** The split supports runtime
  composition, server-side prompt generation, per-app custom libraries, and a
  simpler non-generic API. All are in scope; none is deferred.

- **Definition models live in `openui_core` with `dart_mappable`.**
  *Rationale:* keeps core Flutter-free while making libraries serializable.
  Add `dart_mappable` as a core dependency. Models: `ComponentDefinition`
  (name, description, schema, internal), `ToolDefinition` (name, description,
  input, output), `LibraryDefinition` (components, tools, libraryPrompt).
  Prompt generation (`generatePrompt`, `LibraryDefinition.prompt()`) operates
  on `LibraryDefinition` only. `LibraryDefinition.extend()` stays in core as a
  pure-data combiner (last-write-wins on duplicate names), replacing
  `Library<W>.extend()`.

- **`Schema` serializes through dart_mappable custom hooks.**
  *Rationale:* `json_schema_builder` `Schema` is not natively mappable. Store
  the wire format as `Map<String, dynamic>` in generated JSON, with
  `@MappableField` decode/encode hooks that call `Schema.fromMap()` /
  `schema.value`. At runtime, definition models expose typed `Schema` fields
  for prop evaluation and prompt generation. Do not downgrade to raw maps in
  the public Dart API.

- **Remove all generics; hardcode `Widget` in `openui`.**
  *Rationale:* user requirement. Delete `Component<W>`, `Library<W>`,
  `ComponentRender<W>`. Replace with:
  ```dart
  typedef ComponentRender = Widget Function(
    EvalContext context,
    Map<String, Object?> props,
    Widget Function(AstNode node, EvalContext context) renderNode,
    String statementId,
  );
  typedef ToolExecutor = Future<ToolResult> Function(Map<String, Object?> args);
  ```
  Core tests that used `Component<String>` / `Library<String>` either move to
  `openui` widget tests or are rewritten to test definition/prompt logic
  without render callbacks.

- **Tools mirror components.** Replace the `Tool` abstract class (which bundles
  definition + `callTool`) with `ToolDefinition` in core and `ToolExecutor` in
  the tool registry. *Rationale:* consistent model; `openui_mcp` adapts MCP
  tools into executors + definitions rather than implementing `Tool`.

- **Registries live in `openui`.**
  *Rationale:* user chose registry classes over raw maps or a bundled config
  object. Proposed shape:
  ```dart
  class ComponentRegistry {
    ComponentRegistry({required Map<String, ComponentRender> renderers});
    ComponentRender? operator [](String name);
    // optional: validateAgainst(LibraryDefinition defs) → missing/extra report
  }
  class ToolRegistry {
    ToolRegistry({required Map<String, ToolExecutor> executors});
    ToolExecutor? operator [](String name);
  }
  ```
  `Renderer` constructor gains `library`, `componentRegistry`, `toolRegistry`
  (replacing monolithic `library: Library<Widget>`).

- **Renderer uses dual lookup: definitions for schemas, registries for behavior.**
  *Rationale:* today's `Library<Widget>` serves two roles during dispatch —
  prop resolution reads `component.schema` (`_resolveProps`,
  `evaluateElementProps`), while render reads `component.render`. After the
  split, the renderer looks up `library.component(name)` for schema/metadata
  and `componentRegistry[name]` for the render callback. Same split for tools:
  `library.tool(name)` for prompt/dispatch metadata,
  `toolRegistry[name]` for execution. This is not optional — both are required
  at dispatch time.

- **Missing renderers fail lazily at dispatch, matching today's behavior.**
  *Rationale:* when a component appears in source but has no registered
  renderer, dispatch falls through to the existing error/unresolved path
  (`onError`, `meta.unresolved`). Do not require construction-time validation
  in v1. Optional `ComponentRegistry.validateAgainst(LibraryDefinition)` for
  tests and debug builds only.

- **Schemas stay as `json_schema_builder` `Schema`.**
  *Rationale:* no reason to downgrade to raw maps; `Schema` already
  round-trips through JSON maps and drives prompt generation + prop evaluation
  (`evaluateElementProps`, `x-reactive`, `x-action`).

- **`openui_components` exports definition + render map.**
  *Rationale:* keeps the package as the built-in vocabulary layer. Replace
  `standardLibrary()` with `standardLibraryDefinition()` and add
  `standardComponentRenderers` (a `Map<String, ComponentRender>` or factory for
  `ComponentRegistry`). Each component file splits into:
  1. Definition factory returning `ComponentDefinition`
  2. Render function registered under the component name

- **Code-first authoring; JSON runtime loading deferred.**
  *Rationale:* models are serializable today for prompts/export; loading
  libraries from assets/network is a future capability enabled by this refactor,
  not part of v1 scope.

- **Clean break, no deprecation aliases.**
  *Rationale:* pre-1.0; update all packages (`openui_core`, `openui`,
  `openui_components`, `openui_mcp`, example app, tests, docs) in one pass.

- **Logic that moves from core to openui.**
  *Rationale:* anything tied to `Widget` or render callbacks:
  - `ComponentRender` typedef and `ComponentRegistry`
  - `ToolExecutor` typedef and `ToolRegistry`
  - Renderer-side prop resolution that pre-renders child widgets
    (`_resolveProps` in `renderer.dart`) — already in openui; stays
  - `evaluateElementProps` can remain in core (generic-agnostic, used for
    reactive prop markers)

  Stays in core:
  - Parser, AST, evaluator, store, actions, merge
  - `ComponentDefinition`, `ToolDefinition`, `LibraryDefinition`
  - `ToolResult`, error types
  - Prompt generation from definitions
  - `ReactiveAssign`, `isReactiveAssign`, `evaluateElementProps`

## Target API Shape (illustrative)

```dart
// openui_core
@MappableClass()
class ComponentDefinition with ComponentDefinitionMappable {
  const ComponentDefinition({
    required this.name,
    required this.schema,
    this.description,
    this.internal = false,
  });
  final String name;
  final Schema schema;
  final String? description;
  final bool internal;
}

// openui_components
LibraryDefinition standardLibraryDefinition() => LibraryDefinition(
  components: [buttonDefinition(), stackDefinition(), /* ... */],
  tools: [],
);

ComponentRegistry standardComponentRegistry() => ComponentRegistry(
  renderers: {
    'Button': renderButton,
    'Stack': renderStack,
    // ...
  },
);

// app
Renderer(
  library: standardLibraryDefinition().extend(
    tools: [snackbarToolDefinition()],
  ),
  componentRegistry: standardComponentRegistry(),
  toolRegistry: ToolRegistry(executors: {
    'show_snackbar': showSnackbar,
    'fetch_products': fetchProducts,
  }),
  response: streamedText,
)
```

## Migration Impact

| Area | Change |
|---|---|
| `packages/openui_core/lib/src/library/library.dart` | Replace `Component<W>`, `Library<W>` with mappable definition models + `extend()` |
| `packages/openui_core/lib/src/tools/tools.dart` | Replace `Tool` abstract class with `ToolDefinition`; keep `ToolResult` |
| `packages/openui_core/lib/src/prompt/prompt.dart` | Accept `LibraryDefinition` instead of `Library<W>` |
| `packages/openui_core/pubspec.yaml` | Add `dart_mappable` + codegen dev dependency |
| `packages/openui/lib/src/renderer.dart` | Dual lookup (definition schema + registry render); remove `Library<Widget>` |
| `packages/openui/lib/src/query_manager.dart` | `LibraryDefinition` + `ToolRegistry` instead of `Library<Widget>` |
| `packages/openui_components/lib/src/components/*.dart` | Split ~17 component files into definition factory + render fn |
| `packages/openui_components/lib/src/openui_library.dart` | `standardLibraryDefinition()` + `standardComponentRegistry()` |
| `packages/openui_mcp/lib/src/mcp_tool.dart` | Produce `(ToolDefinition, ToolExecutor)` pairs |
| `apps/openui_flutter_example/lib/chat/` | Wire definitions + registries; `chat_view.dart` prompt path uses `LibraryDefinition` |
| `docs/architecture.md` | Update data-flow diagram and layer descriptions |
| Tests | Rewrite `library_test.dart` (no `Component<String>`); update renderer/query/MCP/component tests |

**Scope estimate:** medium-large refactor touching ~40 Dart files across 5 packages.
No Lang/parser changes, but every component factory and test harness that builds
a `Library<Widget>` must be updated.

## Open Questions

- **Registry extend/inheritance.** Should registries support `.extend()` like
  today's `Library.extend()`, or is map spread at the app level sufficient?
  Proposal: map spread for v1 (YAGNI). `LibraryDefinition.extend()` handles
  definition merging; registries are merged manually.
- **`openui_mcp` adapter shape.** Does `McpClient.asOpenUITools()` become
  `asOpenUIToolPairs()` returning `List<({ToolDefinition def, ToolExecutor exec})>`,
  or two parallel lists? Decide during planning.
- **Tabs AST re-read.** `Tabs` re-reads raw AST from `ctx.statements[id]` for
  inline labels — render-side behavior unchanged, but confirm the split doesn't
  accidentally move statement access into definition models.
- **Doc drift cleanup.** README references to `defineComponent`, `ToolProvider`,
  `reactive()` should be updated as part of this refactor (already stale).

## Out of Scope

- Loading `LibraryDefinition` from JSON assets or network at runtime
- Bundled helper types in `openui_components` (can follow immediately after)
- Changes to OpenUI Lang syntax, parser, or action semantics
- Folding `openui_components` into `openui`
