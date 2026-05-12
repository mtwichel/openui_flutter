---
date: 2026-05-12
topic: generate-prompt
---

# generatePrompt for openui_core

## What We're Building

A Dart port of the JS `generatePrompt` function, living in the `openui_core` package. The function accepts a `PromptSpec` (components, tools, flags, examples) and returns a complete LLM system prompt string. A companion `Library<W>.prompt(PromptOptions)` method builds the spec automatically from registered component schemas, so callers never need to enumerate components by hand.

The example app replaces the hand-authored `const String openUiLangSystemPrompt` in `dartantic_chat_service.dart` with a call to `library.prompt(PromptOptions(tools: [...]))`.

This work also adds a `description` field to `Component<W>` registration, mirroring the JS `defineComponent` API. Component descriptions flow into the generated prompt as `ComponentName(props...) — description`. Per-prop descriptions are already expressible via JSON schema `description` fields and will be extracted by `_schemaToSignature()`.

## Why This Approach

Three approaches were considered:

- **Direct port** (chosen): `generatePrompt(PromptSpec)` + `Library.prompt()`. Matches the JS API shape exactly, making it straightforward to track JS-side changes. Component signatures auto-derive from each `Component.schema`.
- **Builder pattern**: `PromptBuilder(library).tools([...]).build()`. More Dart-idiomatic but diverges from the JS API surface, making long-term parity harder.
- **Extension method**: `LibraryPromptExtension` on `Library<W>`. Avoids touching the Library class but adds discoverability friction for something central to the library.

The direct port wins because the JS version is the source of truth and the API surfaces should stay aligned as the spec evolves.

## Key Decisions

- **Package placement**: `openui_core` — making `generatePrompt` available to any consumer of the library, not just the example app.
- **Component signatures**: Auto-derived from each `Component.schema` via an internal `_schemaToSignature(JsonSchema)` helper. No changes needed to component registrations.
- **Tool input**: `PromptSpec` accepts `List<ToolSpec>` (name, description, inputSchema, outputSchema), matching the JS `ToolSpec` shape. Callers wire in MCP tool definitions manually.
- **Scope — MVP sections only**: `PromptSpec` fields for the first implementation: `components`, `tools`, `preamble`, `examples`, `additionalRules`. Flags `editMode`, `inlineMode`, `bindings`, and the `toolCalls` Query/Mutation workflow are defined in `PromptSpec` but default to off and produce no output until explicitly enabled.
- **`PromptOptions` vs `PromptSpec`**: `PromptOptions` is the caller-facing type exposed on `Library.prompt()` — it omits `components` (which `Library` fills in from registered schemas). `PromptSpec` is the internal type that adds `components` and is passed to `generatePrompt`. Callers never construct `PromptSpec` directly.
- **Grammar primer**: Embedded as a `const String` inside `generatePrompt`. Avoids a file-read dependency in a library package and keeps the function self-contained. Updated manually when the lang spec changes.
- **Component descriptions**: `Component<W>` gains an optional `description: String?` parameter. This mirrors the JS `defineComponent({ description })` field. The description appears in the generated prompt formatted as `ComponentName(props...) — description`, matching JS behavior.
- **Prop descriptions**: Individual prop descriptions are authored as JSON schema `description` fields (already supported by `json_schema_builder`). `_schemaToSignature()` extracts them and includes them inline in the signature output. No new API surface needed on `Component<W>` for this — it's a schema-level concern.
- **Prompt format for component entries**: `ComponentName(propName: type, ...) — component description`. Prop descriptions appear as inline comments after each prop type, e.g. `label: string /* The button label */`.

## Open Questions

- `_schemaToSignature()`: what Dart type does each JSON schema type map to in the signature string? Needs alignment with how the JS version renders prop types (e.g., `string`, `Action`, `boolean`).
- Does `openui_mcp`'s `McpToolProvider` expose tool schemas in a shape compatible with `ToolSpec`, or does the caller need to adapt them?
