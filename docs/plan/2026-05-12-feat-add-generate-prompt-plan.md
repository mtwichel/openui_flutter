---
title: "feat: add generatePrompt to openui_core"
type: feat
date: 2026-05-12
---

## Add `generatePrompt` to `openui_core`

## Overview

Port the JS `generatePrompt` function to Dart as a first-class API in `openui_core`. A companion `Library<W>.prompt(PromptOptions)` extension method builds the prompt automatically from registered component schemas so callers never need to enumerate components by hand.

The example app replaces the hand-authored `const String openUiLangSystemPrompt` in `dartantic_chat_service.dart` with a call to `openuiLibrary().prompt(PromptOptions())`.

This work also adds `description: String?` and `internal: bool` fields to `Component<W>`. `description` flows into the generated prompt as `ComponentName(props...) — description`. `internal: true` flags components like `Col` and `TabItem` that are registered in `openuiLibrary()` but must not appear as standalone components in the LLM prompt.

## Problem Statement

The system prompt in `dartantic_chat_service.dart` is hand-authored and grows stale as new components are added to `openuiLibrary()`. Every new component registration requires a matching manual update to the prompt. The JS reference generates the prompt programmatically from the component registry.

Additionally, `Component<W>` has no `description` or `internal` fields, creating gaps relative to the JS `defineComponent` API and causing components like `Col` (a definitional helper) and `TabItem` (only valid inside `Tabs`) to bleed into the LLM prompt as if they were top-level elements.

## Proposed Solution

Add a `prompt/` module to `openui_core` containing:

- `ToolSpec` — caller-constructed tool metadata (`name`, `description`, `inputSchema`, `outputSchema`)
- `PromptOptions` — caller-facing options passed to `Library<W>.prompt()` (`tools`, `preamble`, `examples`, `additionalRules`)
- `generatePrompt<W>(List<Component<W>> components, PromptOptions options) → String` — builds the complete system prompt from components and options
- `_schemaToSignature(Map<String, Object?> properties) → String` — internal; maps component schema props to a signature string
- `extension LibraryPromptExtension<W> on Library<W>` — adds `.prompt(PromptOptions)`, filters `internal: true` components, and delegates to `generatePrompt`

`PromptSpec` is not introduced. `generatePrompt` takes its two arguments directly.

`Component<W>` gains:
- `description: String?` — optional LLM-facing description, default `null`
- `internal: bool` — when `true`, component is excluded from generated prompts, default `false`

`defineComponent<W>` is updated to accept both. All existing call sites compile unchanged (both fields have defaults).

The extension method approach avoids a circular import: `prompt.dart` imports `library.dart`, so `library.dart` cannot import `prompt.dart`. The extension is exported from the main barrel and is always in scope for any caller that imports `package:openui_core/openui_core.dart`.

### Generated prompt structure

```
<preamble — default or caller-supplied>

GRAMMAR (essential):
<const _kGrammarPrimer — embedded string, see docs/lang-reference.md>

COMPONENTS (use only these):
ComponentName(prop: type, requiredProp: type, optionalProp?: type) — description
ComponentName(prop: type /* prop description */) — description

TOOLS:
ToolName(inputSchema) → outputSchema — description

EXAMPLES:
<caller-supplied examples>

RULES:
<default rules + caller-supplied additionalRules>
```

### `_schemaToSignature` type mapping

| JSON schema `type` | Signature string |
|---|---|
| `"string"` | `string` |
| `"number"` | `number` |
| `"integer"` | `integer` |
| `"boolean"` | `boolean` |
| `"array"` | `array` |
| `"object"` | `object` |
| absent / any other value | `any` |

**Prop optionality**: `_schemaToSignature` reads the component schema's top-level `required: [...]` array. Props in the list render without `?`; all others render with `?`. If no `required` key is present, all props render with `?`. Component schemas in `openui_components` must be updated to add `required` lists for genuinely mandatory props (e.g., `Button.label`, `Card.children`, `Input.name`, `Input.value`).

**Typeless props** (`{}`): render as `any`. Affects `Button.onClick`, `Stack.gap`, and `TabItem.content`. This is acceptable for MVP — the examples section teaches the model usage patterns for these props. A follow-up could add a `x-display-type` extension keyword to the schema to override the rendered type name (e.g., `Action` for `onClick`).

**Reactive props** (`x-reactive: true`): render with their base `type`, stripping the extension keyword. Reactive semantics are a runtime concern.

**Enum values**: props with `type: string` but constrained to specific values (e.g., `variant?: "info" | "warning"`) are not represented by enum annotation in this iteration — the current schemas do not use JSON Schema's `enum` field. The known regression (LLM sees `variant?: string` instead of `variant?: "info" | "warning"`) is acceptable for MVP given the examples section. Adding `enum` to component schemas is a follow-up.

**Prop descriptions**: extracted from the JSON schema `description` field of each property. Format: `propName: type /* description */`.

### DartanticChatService wiring

`DartanticChatService` receives a required `String systemPrompt` constructor parameter. `_makeChat` is updated to accept the system prompt. The old `openUiLangSystemPrompt` const is deleted. The construction site in the example app passes `openuiLibrary().prompt(PromptOptions())`.

## Implementation Tasks

### `openui_core` — library changes

- [ ] Add `description: String?` and `internal: bool` to `Component<W>` in `packages/openui_core/lib/src/library/library.dart:46`
- [ ] Update `defineComponent<W>` at `packages/openui_core/lib/src/library/library.dart:70` to accept `description` and `internal`, forwarding them to the constructor
- [ ] Add `Iterable<Component<W>> get components` getter to `Library<W>` (exposes `_byName.values`; used by `LibraryPromptExtension`)

### `openui_core` — prompt module

- [ ] Create `packages/openui_core/lib/src/prompt/prompt.dart` with:
  - `@experimental ToolSpec` (immutable, `name: String`, `description: String`, `inputSchema: Map<String, Object?>`, `outputSchema: Map<String, Object?>?`)
  - `@experimental PromptOptions` (immutable, `tools: List<ToolSpec> = const []`, `preamble: String?`, `examples: List<String> = const []`, `additionalRules: List<String> = const []`)
  - `@experimental String generatePrompt<W>(List<Component<W>> components, {PromptOptions options = const PromptOptions()})`
  - `String _schemaToSignature(Map<String, Object?> properties, {List<String> required = const []})` (internal)
  - `const String _kGrammarPrimer` (embedded; mirrors the grammar section of `docs/lang-reference.md`)
  - `@experimental extension LibraryPromptExtension<W> on Library<W>` with `String prompt(PromptOptions options)`; filters `internal: true` via `components.where((c) => !c.internal)`

### `openui_core` — barrel exports

- [ ] Add to `packages/openui_core/lib/openui_core.dart`:
  ```dart
  export 'src/prompt/prompt.dart'
      show
          LibraryPromptExtension,
          PromptOptions,
          ToolSpec,
          generatePrompt;
  ```
  Note: `_schemaToSignature` and `_kGrammarPrimer` stay private; `generatePrompt` is exported for callers who need to bypass `Library.prompt()`.

### `openui_components` — component registrations

- [ ] Update `objectSchema` calls in all component files to add `required: [...]` for mandatory props. Files and required props:
  - `stack.dart` — `required: ['children']`
  - `card.dart` — `cardComponent: required: ['children']`; `cardHeaderComponent: required: ['title']`
  - `callout.dart` — `required: ['text']`
  - `text_content.dart` — `required: ['text']`
  - `button.dart` — `buttonComponent: required: ['label']`; `buttonsComponent: required: ['children']`
  - `form.dart` — `formComponent: required: ['name', 'children']`; `formControlComponent: required: ['label', 'children']`
  - `input.dart` — `required: ['name', 'value']`
  - `select.dart` — `required: ['options', 'value']`
  - `table.dart` — `tableComponent: required: ['columns', 'rows']`; `colComponent: required: ['name']`
  - `tabs.dart` — `tabsComponent: required: ['items']`; `tabItemComponent: required: ['label', 'content']`
  - `markdown.dart` — `required: ['text']`
  - `image.dart` — `required: ['src']`
  - `code_block.dart` — `required: ['code']`
  - `separator.dart` — no required props
  - `bar_chart.dart`, `line_chart.dart` — `required: ['data']` (confirm prop names)
- [ ] Add `description:` to all `defineComponent()` calls (description strings are implementation detail; keep them concise and in plain English)
- [ ] Add `internal: true` to `colComponent()` in `table.dart` and `tabItemComponent()` in `tabs.dart`

### Example app wiring

- [ ] Update `apps/openui_flutter_example/lib/src/llm_chat/dartantic_chat_service.dart`:
  - Change `_makeChat(String agentString)` to `_makeChat(String agentString, String systemPrompt)` (no longer static — or pass as parameter)
  - Add `required String systemPrompt` to the `DartanticChatService` constructor
  - Delete `const String openUiLangSystemPrompt`
  - Add `// ignore_for_file: experimental_member_use` since the file calls `.prompt()`
- [ ] Update the `DartanticChatService` construction site (find via `grep DartanticChatService`) to pass `systemPrompt: openuiLibrary().prompt(const PromptOptions())`

### Tests

- [ ] Add to `packages/openui_core/test/src/library/library_test.dart`:
  - `Component.description` defaults to `null`
  - `defineComponent` with `description:` sets the field
  - `Component.internal` defaults to `false`
  - `defineComponent` with `internal: true` sets the field
- [ ] Create `packages/openui_core/test/src/prompt/prompt_test.dart`:
  - `generatePrompt` with empty components returns a string containing the grammar primer
  - Component with `description` renders `Name(prop: type) — description`
  - Component without `description` renders `Name(prop: type)` (no ` — ` suffix)
  - Component with no props renders `Name()` (no trailing comma or space)
  - Prop in `required` list renders without `?`; prop outside renders with `?`
  - Prop with schema `{}` renders as `any`
  - Prop with `x-reactive: true` renders its base `type`, not `x-reactive`
  - Prop with JSON schema `description` renders `/* description */` inline
  - `PromptOptions.tools` non-empty produces a `TOOLS:` section
  - `PromptOptions.tools` empty (`const []`) omits the `TOOLS:` section
  - Caller-supplied `preamble` replaces the default preamble
  - `LibraryPromptExtension.prompt` output contains every name from `library.names` (use a pure-`String` stub library)
  - `LibraryPromptExtension.prompt` excludes components where `internal: true`
  - Snapshot / golden test: `generatePrompt([stubCard, stubButton], options: const PromptOptions())` output matches a golden string embedded in the test file (guard against grammar primer drift)

## Acceptance Criteria

- [ ] `generatePrompt([], options: const PromptOptions())` returns a non-empty string containing the grammar primer
- [ ] Each non-internal registered component appears in the output as `ComponentName(...)` with correct prop types
- [ ] Required props have no `?`; optional props have `?`
- [ ] Typeless props render as `any`
- [ ] `internal: true` components are absent from `library.prompt()` output
- [ ] `ToolSpec` entries appear under a `TOOLS:` heading; empty tools list omits the section
- [ ] Prop `description` fields from JSON schema render as `/* description */` inline comments
- [ ] Component `description` field renders as ` — description` suffix when set; absent when null
- [ ] `openuiLibrary().prompt(const PromptOptions())` output contains all component names registered in `openuiLibrary()` minus `Col` and `TabItem`
- [ ] `DartanticChatService` uses the generated prompt; existing chat behavior is unchanged
- [ ] All existing `openui_core` tests pass
- [ ] `Component<W>` `description: null`, `internal: false` defaults preserve backward compatibility — existing `defineComponent` call sites compile unchanged

## Known Gaps (not in scope)

- **Enum values in signatures**: props like `variant` accept only specific literals (`"info" | "warning"`) but the schemas use `type: string`. The generated signature loses this constraint. Fix requires adding `enum: [...]` to component schemas.
- **Named type overrides for typeless props**: `onClick: {}` renders as `any` rather than `Action`. Fix requires a `x-display-type` schema extension or a per-prop lookup table.
- **`McpToolProvider` → `ToolSpec` adapter**: callers must manually construct `ToolSpec` instances from MCP tool listings. No bridge from `mcp.Tool` to `ToolSpec` exists.
- **Grammar primer staleness detection**: `_kGrammarPrimer` drifts from `docs/lang-reference.md` silently. The snapshot test in `prompt_test.dart` detects output changes but not source drift.
