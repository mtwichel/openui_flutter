## 0.0.1-dev.2

- **BREAKING**: Replace `openuiLibrary()` / `openuiChatLibrary()` with
  `standardLibraryDefinition()` + `standardComponentRegistry()`. Each component
  file exports a `*Definition()` factory and a `render*` function.
- Point pubspec `repository`, `homepage`, and `issue_tracker` URLs at `github.com/mtwichel/openui_flutter`.

## 0.0.1-dev.1

- **feat**: 21 built-in components ready for the renderer:
  - **Layout** — `Stack`, `Card` + `CardHeader`, `Separator`, `Callout`.
  - **Content** — `TextContent` (semantic size variants),
    `MarkDownRenderer` (16 ms debounce while streaming), `Image`
    (broken-URL fallback), `CodeBlock` (selectable, monospace).
  - **Forms** — `Form` + `FormControl`, `Input` (reactive value), `Select`
    (reactive value), `Button`, `Buttons`.
  - **Data** — `Table` + `Col` with pagination, `Tabs` + `TabItem`.
  - **Charts** — `BarChart`, `LineChart` (fl_chart, multi-series).
- **feat**: `openuiLibrary()` and `openuiChatLibrary()` build a
  `Library<Widget>` containing every registered component.
- **feat**: `kSpacingTokens` / `kTextSizeTokens` / `resolveSpacing` —
  shared design tokens for component layout.
- **chore**: package scaffold (Phase 0).
