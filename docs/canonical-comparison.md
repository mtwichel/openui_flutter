# Canonical OpenUI vs openui_flutter

This document compares **OpenUI Lang** as defined by the canonical reference implementation ([thesysdev/openui](https://github.com/thesysdev/openui), local clone at `/Users/marcustwichel/Developer/AI/openui`) with this Flutter port (`openui_flutter`). The goal is **1:1 language mirroring**: the same OpenUI Lang source an LLM produces for the JS stack should parse, evaluate, and render correctly here without rewriting.

**Canonical spec:** [OpenUI Lang v0.5](https://www.openui.com/docs/openui-lang/specification-v05)  
**Dart-side reference:** [lang-reference.md](lang-reference.md) (claims v0.5 fidelity; several items below are stale or divergent)

---

## 1. Executive summary

### What already aligns

| Area | Notes |
|------|--------|
| Program shape | Line-oriented `identifier = expression`, one statement per line |
| Entry point | `root = …` (root component name comes from the library) |
| State | `$name = default`, reads via `$name`, inline `$name = expr` in expressions |
| Operators | Arithmetic, comparison, logical, unary `!`/`-`, ternary `? :`, `.` and `[]` |
| Forward references | `root = Stack([chart])` before `chart = …` is defined |
| Streaming | `StreamParser.push` / `set`, `autoClose`, `meta.incomplete` / `unresolved` / `orphaned` |
| Lazy iteration | `@Each(array, "varName", template)` with named loop variable |
| Action steps (subset) | `@Set`, `@Reset`, `@Run`, `@ToAssistant` with click-time re-evaluation |
| Reactive props | `reactive(...)` schema → two-way `$` binding |
| Edit merge (core only) | `mergeStatements(existing, patch)` ported; not wired in `Renderer` |
| Schema validation (partial) | `unknown-component`, `missing-required`, `excess-args` via integration `parse()` |

### Where we are not 1:1 today

| Gap | Impact |
|-----|--------|
| **Positional vs named component args** | **Partial** — positional-only syntax + render-path mapping shipped; canonical Zod **property order** still differs for some components (`Stack`, `Button`, …) until schema reorder |
| **`Query(...)` vs `$var = @Query(...)`** | **Partial** — canonical `Query(...)` parses; full dashboard parity still needs array pluck |
| **`Action([...])` / `action` prop vs `onClick: [...]`** | **Resolved** — `action` + `Action([...])`; bare arrays rejected |
| **Array pluck** (`data.rows.title`) | **High** — breaks canonical Table/Chart column idioms |
| **Builtin set** (`@Sum`, `@Filter` shape, etc.) | **High** for data-heavy UIs |
| **Query lifecycle** (auto re-fetch, refresh interval, defaults object) | **High** for reactive dashboards |
| **Standard library** (~45 vs 17 components) | **High** for full generative UI parity; language can parse unknown components but not render |
| **Tooling** (`jsonToOpenUI`, `inlineMode` in stream parser) | **Medium** for chat/edit flows |

### Intentional Flutter-only extensions

Documented in [plan/2026-05-15-feat-at-query-builtin-plan.md](plan/2026-05-15-feat-at-query-builtin-plan.md):

- **`$var = @Query(toolName, named: value, …)`** — replaces canonical `name = Query("tool", {args}, {defaults}, refreshSec?)`
- **`@Map(list, transformRef)`** — not in canonical `builtins.ts`

Restoring strict 1:1 parity requires a product decision on whether to support canonical syntax alongside these extensions or revert them.

---

## 2. Language syntax and grammar

### 2.1 Summary table

| Topic | Canonical (v0.5) | Flutter port | Parity |
|-------|------------------|--------------|--------|
| Component arguments | **Positional only** — mapped to props by Zod/schema key order ([spec core rules](https://www.openui.com/docs/openui-lang/specification-v05)) | **Positional-only**; named component args rejected at parse; mapped by Dart schema property order | **Partial** (order) |
| Query statements | `data = Query("tool", {args}, {defaults}, refreshSec?)` | `data = Query("tool", {args}, {defaults}, refreshSec?)`; `@Query` removed | **Partial** |
| Mutation | `result = Mutation("tool", {args})` positional | `Mutation(name: "...", args: {...})` named | **Partial** |
| Button actions | `Button("Label", Action([@Set(...)]))` — prop **`action`** | `Button("Label", Action([@Set(...)]))` — prop **`action`**; bare arrays rejected | **Yes** |
| `@OpenUrl` | Spec + `ACTION_STEPS` in lang-core | Not in `actions.dart` dispatcher | **No** |
| `@Map` | Not in canonical | In `functionalBuiltins` | Flutter-only |
| Comments | Not in language | Not in v0.1 | **Yes** |

**Sources:** Canonical spec § Core Rules; Flutter `packages/openui_core/test/src/library/library_test.dart` (`positional args are dropped`); `packages/openui_core/lib/src/actions/actions.dart` (rejects `Action(...)`).

### 2.2 Side-by-side: reactive counter

**Canonical (positional, `action` prop):**

```text
$count = 0
root = Stack([title, controls])
title = TextContent("Count: " + $count, "large-heavy")
controls = Stack([incBtn, resetBtn], "row")
incBtn = Button("Increment", Action([@Set($count, $count + 1)]), "primary")
resetBtn = Button("Reset", Action([@Reset($count)]), "secondary")
```

**Flutter today (named props, `onClick` array):**

```text
$count = 0
root = Card(children: [
  TextContent(text: "Count: " + $count, size: "large-heavy"),
  Stack(direction: "row", children: [
    Button(label: "Increment", onClick: [@Set($count, $count + 1)]),
    Button(label: "Reset", variant: "secondary", onClick: [@Reset($count)])
  ])
])
```

**What breaks if you paste canonical into Flutter:**

- Positional `TextContent("…", "large-heavy")` — `size` not bound (positional dropped in `evaluateElementProps`).
- `Action([...])` — not accepted; need bare `[...]` on `onClick`.
- Prop name `action` vs `onClick`.

### 2.3 Side-by-side: query-driven chart

**Canonical:**

```text
$days = "7"
root = Stack([title, filter, chart])
title = TextContent("Showing last " + $days + " days")
filter = Select("days", $days, [SelectItem("7", "7 days"), SelectItem("30", "30 days")])
data = Query("analytics", {days: $days}, {rows: []})
chart = LineChart(data.rows.day, [Series("Views", data.rows.views)])
```

**Flutter today:** same `Query(...)` declaration; example app still uses named component props in scripts.

**What still breaks:**

- `data.rows.day` array pluck — evaluates to `null` in Flutter `_evalMember` (no pluck).
- `Select("days", $days, [...])` positional — props not bound.
- `LineChart` / `Series` — `Series` not in Flutter standard library; chart prop shapes differ.

### 2.4 Side-by-side: form with validation

**Canonical:**

```text
root = Stack([title, form])
title = TextContent("Contact Us", "large-heavy")
form = Form("contact", btns, [nameField, emailField])
nameField = FormControl("Name", Input("name", "Your name", "text", {required: true, minLength: 2}))
emailField = FormControl("Email", Input("email", "you@example.com", "email", {required: true, email: true}))
btns = Buttons([Button("Submit", Action([@ToAssistant("Submit")]), "primary")])
```

**Flutter example script** ([`04_form.txt`](../apps/openui_flutter_example/assets/scripts/04_form.txt)) uses `Form(name:, children:)` but **`Form` is not registered** in `standardLibraryDefinition()` — the script does not render a form shell even in this repo.

---

## 3. Builtins and expressions

### 3.1 Functional (data) builtins

| Builtin | Canonical | Flutter | Notes |
|---------|-----------|---------|-------|
| `@Count` | Yes | Yes | Aligned |
| `@Sum`, `@Avg`, `@Min`, `@Max` | Yes | **No** | KPI / aggregate prompts |
| `@First`, `@Last` | Yes | **No** | |
| `@Filter` | `(array, field, op, value)` — `==`, `!=`, `>`, `<`, `>=`, `<=`, `contains` | `(list, predicateRef)` with `$item` / `$index` | **Different contract** |
| `@Sort` | `(array, field, direction?)` | **No** | |
| `@Round`, `@Abs`, `@Floor`, `@Ceil` | Yes | **No** | |
| `@Each` | `(array, varName, template)` lazy | Same | Largely aligned |
| `@Map` | **No** | Yes | Flutter-only |
| `@Query` | **No** (statement-level `Query` instead) | **No** (parse error; use `Query(...)`) | Aligned |

**Canonical registry:** `openui/packages/lang-core/src/parser/builtins.ts`  
**Flutter registry:** `packages/openui_core/lib/src/eval/builtins.dart`

### 3.2 Action builtins

| Step | Canonical | Flutter |
|------|-----------|---------|
| `@Set` | Yes | Yes |
| `@Reset` | Yes | Yes |
| `@Run` | Yes (query/mutation refs + tools) | Yes |
| `@ToAssistant` | Yes | Yes |
| `@OpenUrl` | Yes | **No** |
| `Action([...])` container | Required on `action` prop | **Rejected** — only non-empty `ArrayLit` on `x-action` props |

**Flutter:** `packages/openui_core/lib/src/actions/actions.dart` — `actionPlanFromAst` returns `null` for `Action(...)`.

### 3.3 Array pluck (member access on arrays)

Canonical: `data.rows.title` when `data.rows` is an array returns an array of each row’s `title` field (column extraction for `Table` / charts).

```211:216:openui/packages/lang-core/src/runtime/evaluator.ts
      // Array pluck: if obj is an array, extract field from every element
      if (Array.isArray(obj)) {
        if (node.field === "length") return obj.length;
        return obj.map((item: any) => item?.[node.field] ?? null);
      }
```

Flutter: `_evalMember` only handles `Map`, `List.length`, and `String.length` — **no pluck**.

```294:299:packages/openui_core/lib/src/eval/evaluator.dart
Object? _evalMember(Object? target, String name) {
  if (target is Map<String, Object?>) return target[name];
  if (target is List<Object?> && name == 'length') return target.length;
  if (target is String && name == 'length') return target.length;
  return null;
}
```

**Impact:** Canonical examples like `Col("Title", data.rows.title)` and `LineChart(data.rows.day, [Series("Views", data.rows.views)])` do not evaluate correctly here.

### 3.4 Positional args in the renderer path

Integration-style `parse()` in `packages/openui_core/lib/src/parse/parse.dart` **does** map positional args to schema order. The **`Renderer` / `evaluateElementProps` path does not**:

```232:241:packages/openui_core/test/src/library/library_test.dart
    test('positional args are dropped', () {
      final schema = Schema.object();
      final ctx = EvalContext(statements: const [], store: Store());
      final props = evaluateElementProps(
        call: callFor('a = Stack("positional", named: 1)'),
        schema: schema,
        context: ctx,
      );
      expect(props.keys, ['named']);
    });
```

Canonical programs are positional-only, so the primary render path must accept them for 1:1 parity.

---

## 4. Data layer (Query / Mutation)

| Behavior | Canonical (`queryManager.ts`) | Flutter (`query_manager.dart`) |
|----------|------------------------------|--------------------------------|
| Declaration | `name = Query("tool", {args}, {defaults}, refreshSec?)` | Same |
| Loading UI | Renders **defaults** object until fetch completes | Same via `getResult` |
| Re-fetch when `$` in query args change | **Yes** — dependency tracking | **Yes** — `_syncQueries` on store change |
| Refresh interval (4th positional arg) | **Yes** — timer lifecycle | **Yes** |
| Mutation | `mutation = Mutation("tool", {args})`; run via `@Run(mutation)` | `Mutation(name: "...", args: {...})`; `fireMutation` path |
| Result storage | Query manager + eval context | `QueryManager` only (store holds `$` state) |

**Canonical reference:** `openui/packages/lang-core/src/runtime/queryManager.ts`.  
**Flutter reference:** `packages/openui/lib/src/query_manager.dart`.

---

## 5. Standard component library

### 5.1 Coverage summary

| Library | Component count (approx.) | Root |
|---------|---------------------------|------|
| Canonical `openuiLibrary` | 45 named exports in `openuiLibrary.tsx` | `Stack` |
| Canonical `openuiChatLibrary` | 52 (includes chat-specific + most of openui) | `Card` (locked `ChatCard`) |
| Flutter `standardLibraryDefinition()` | **17** | (implicit via `root = …` in source) |

Flutter registration: `packages/openui_components/lib/src/openui_library.dart`.

### 5.2 Full component checklist

Status key: **Shipped** = in `standardLibraryDefinition()` + `standardComponentRegistry()`; **Missing** = not registered; **N/A** = chat-library-only in canonical.

#### Layout

| Component | Canonical `openuiLibrary` | Canonical `openuiChatLibrary` | Flutter | Notes |
|-----------|---------------------------|-------------------------------|---------|-------|
| `Stack` | Yes | No (chat uses Card only) | **Shipped** | |
| `Tabs` | Yes | Yes | **Shipped** | |
| `TabItem` | Yes | Yes | **Shipped** | |
| `Accordion` | Yes | Yes | Missing | |
| `AccordionItem` | Yes | Yes | Missing | |
| `Steps` | Yes | Yes | Missing | |
| `StepsItem` | Yes | Yes | Missing | |
| `Carousel` | Yes | Yes | Missing | |
| `Separator` | Yes | Yes | **Shipped** | |
| `Modal` | Yes | No | Missing | |

#### Content

| Component | openuiLibrary | openuiChatLibrary | Flutter | Notes |
|-----------|---------------|-------------------|---------|-------|
| `Card` | Yes | Yes (ChatCard) | **Shipped** | Chat root wrapper not ported |
| `CardHeader` | Yes | Yes | **Shipped** | |
| `TextContent` | Yes | Yes | **Shipped** | Positional `(text, size)` vs named `text`/`size` |
| `MarkDownRenderer` | Yes | Yes | **Shipped** | |
| `Callout` | Yes | Yes | **Shipped** | Canonical: `(variant, title, body, $show?)`; Flutter: `text` + `variant` only |
| `TextCallout` | Yes | Yes | Missing | |
| `Image` | Yes | Yes | **Shipped** | |
| `ImageBlock` | Yes | Yes | Missing | |
| `ImageGallery` | Yes | Yes | Missing | |
| `CodeBlock` | Yes | Yes | Missing | Documented in CHANGELOG, not registered |

#### Tables

| Component | openuiLibrary | Flutter | Notes |
|-----------|---------------|---------|-------|
| `Table` | Yes | **Shipped** | Column-oriented `Col` pattern |
| `Col` | Yes | **Shipped** | |

#### Charts (2D)

| Component | openuiLibrary | Flutter | Notes |
|-----------|---------------|---------|-------|
| `BarChart` | Yes (`BarChartCondensed`) | **Shipped** | Name `BarChart` in Lang |
| `LineChart` | Yes (`LineChartCondensed`) | **Shipped** | |
| `AreaChart` | Yes | Missing | |
| `RadarChart` | Yes | Missing | |
| `HorizontalBarChart` | Yes | Missing | |
| `Series` | Yes | Missing | Required for canonical chart syntax |

#### Charts (1D)

| Component | openuiLibrary | Flutter |
|-----------|---------------|---------|
| `PieChart` | Yes | Missing |
| `RadialChart` | Yes | Missing |
| `SingleStackedBarChart` | Yes | Missing |
| `Slice` | Yes | Missing |

#### Charts (scatter)

| Component | openuiLibrary | Flutter |
|-----------|---------------|---------|
| `ScatterChart` | Yes | Missing |
| `ScatterSeries` | Yes | Missing |
| `Point` | Yes | Missing |

#### Forms

| Component | openuiLibrary | Flutter | Notes |
|-----------|---------------|---------|-------|
| `Form` | Yes | Missing | Example `04_form.txt` uses unregistered `Form` |
| `FormControl` | Yes | Missing | |
| `Label` | Yes | Missing | |
| `Input` | Yes | **Shipped** | Reactive `value` works without `Form` |
| `TextArea` | Yes | Missing | |
| `Select` | Yes | **Shipped** | |
| `SelectItem` | Yes | Missing | |
| `DatePicker` | Yes | Missing | |
| `Slider` | Yes | Missing | |
| `CheckBoxGroup` | Yes | Missing | |
| `CheckBoxItem` | Yes | Missing | |
| `RadioGroup` | Yes | Missing | |
| `RadioItem` | Yes | Missing | |
| `SwitchGroup` | Yes | Missing | |
| `SwitchItem` | Yes | Missing | |

#### Buttons

| Component | openuiLibrary | Flutter | Notes |
|-----------|---------------|---------|-------|
| `Button` | Yes | **Shipped** | `action` + `Action([...])`; `text` variant aliases tertiary |
| `Buttons` | Yes | Missing | Documented in CHANGELOG, not registered |

#### Data display

| Component | openuiLibrary | Flutter |
|-----------|---------------|---------|
| `TagBlock` | Yes | Missing |
| `Tag` | Yes | Missing |

#### Chat-only (canonical `openuiChatLibrary`)

| Component | Flutter | Notes |
|-----------|---------|-------|
| `ListBlock` | Missing | |
| `ListItem` | Missing | |
| `FollowUpBlock` | Missing | |
| `FollowUpItem` | Missing | |
| `SectionBlock` | Missing | |
| `SectionItem` | Missing | |

`openuiChatLibrary()` was **removed** from Flutter (`openui_components` CHANGELOG); `lang-reference.md` still mentions it (stale).

### 5.3 Prop / schema deltas (shipped components)

| Component | Canonical (Zod / positional order) | Flutter schema |
|-----------|-----------------------------------|----------------|
| `Button` | `label`, `action?`, `variant?` (`primary` \| `secondary` \| `tertiary`), `type?`, `size?` | `label`, `action` (`x-action`), `variant` (`primary` \| `secondary` \| `text` → tertiary) |
| `Callout` | `(variant, title, body, $show?)` | `text`, `variant` |
| `Stack` | `(children, direction?, gap?, align?, justify?, wrap?)` | Named `children`, `direction`, … |
| `Card` | Varies | Named `children` |

**Form validation rules** (`required`, `email`, `minLength`, …): canonical `packages/lang-core/src/utils/validation.ts` — **not ported** to Flutter.

---

## 6. Parser, streaming, and tooling

| Feature | Canonical | Flutter | Parity |
|---------|-----------|---------|--------|
| `mergeStatements` | Used in incremental / edit flows | Implemented in `openui_core`; **Renderer never calls it** (Acceptance Gap A17) | Partial |
| `jsonToOpenUI` | `packages/lang-core/src/parser/serialize.ts` | **Not present** | No |
| Fence extraction in stream parser | `extractFence` in `parser.ts`; `inlineMode` in prompts | Fences in `parse()` / `mergeStatements` only; **not** in `StreamParser` | No |
| Prompt flags | `inlineMode`, `toolCalls`, `editMode`, … | `generatePrompt` / `library.prompt()` — teaches canonical `Query(...)`, named props | Partial |
| Validation error codes | Rich set (`unknown-component`, `inline-reserved`, …) | Partial via `parse.dart`; renderer path differs | Partial |

**Prompt divergence:** Canonical and Flutter prompts both document positional `Query(...)` / `Action([...])`. Component calls in Flutter prompts may still teach named props where the Dart port accepts them.

---

## 7. Runtime and host integration

Documented acceptance gaps ([lang-reference.md](lang-reference.md)):

| ID | Topic | Canonical expectation | Flutter today |
|----|--------|----------------------|---------------|
| A5 | Streaming a11y | Live region on streaming text | `TextContent` uses `Semantics(liveRegion:)` — partial |
| A6 | Actions while streaming | — | Actions disabled on `meta.incomplete` statements |
| A7 | Image errors | Broken URL handling | Partial |
| A12 | Multi-thread chat | — | Not implemented |
| A13 | Persistence | — | Not implemented |
| A14 | Error boundary | — | No concurrent-render handling |
| A17 | `mergeStatements` | Wired in edit flows | Core only |
| A21 | Stream adapters | `langgraph`, `openai-readable-stream`, etc. | Transport-agnostic `push(String)` only |

**Out of scope (both v0.1 / v0.5 language):** comments, user-defined functions, imports — aligned as “not in language.”

### Stale documentation in this repo (fix when mirroring)

| Doc | Issue |
|-----|--------|
| [lang-reference.md](lang-reference.md) | Still lists `openuiChatLibrary()` |
| [architecture.md](architecture.md) | References `openui_test_helpers` package (not in tree); diagram mentions `@OpenUrl` |
| [openui_core README](packages/openui_core/README.md) | Historical `OpenUrl` mentions |

---

## 8. Recommended parity phases

Ordered for **language** 1:1 first; widgets can trail.

1. **Syntax compatibility layer** — Accept canonical positional component calls; map to named props via schema key order in `evaluateElementProps`. Accept `Query(...)` / `Mutation(...)` and aliases `action` / `Action([...])` alongside current forms (or migrate with a breaking-change window).
2. **Evaluator parity** — Array pluck; full data builtin set; `@Filter` canonical overload (or dual overload). Decide fate of `@Map`.
3. **Query manager parity** — Defaults object, reactive re-fetch when `$` in args change, refresh interval; document or align loading semantics (`null` vs defaults).
4. **Prompt + fixtures** — Regenerate prompts/examples from canonical `openuiExamples` / `openuiChatExamples`; cross-repo golden tests.
5. **Component library** — Close checklist §5.2; `Form` + validation rules.
6. **Tooling** — Port `jsonToOpenUI`; wire `mergeStatements` in renderer edit path; `inlineMode` fence extraction on stream ingress.

---

## Appendix A: Canonical program — what breaks in Flutter today

Paste this canonical table example (from `openuiLibrary.tsx` `openuiExamples`) into the Flutter `Renderer` with `standardLibraryDefinition()`:

```text
root = Stack([title, tbl])
title = TextContent("Top Languages", "large-heavy")
tbl = Table([Col("Language", langs), Col("Users (M)", users), Col("Year", years)])
langs = ["Python", "JavaScript", "Java", "TypeScript", "Go"]
users = [15.7, 14.2, 12.1, 8.5, 5.2]
years = [1991, 1995, 1995, 2012, 2009]
```

| Failure mode | Cause |
|--------------|--------|
| `TextContent` missing `size` / wrong text | Positional args dropped — `text` and `size` not bound |
| `Table` / `Col` wrong or empty | Positional `Table([...])`, `Col("Language", langs)` not mapped |
| Works for `langs` / `users` / `years` arrays | Top-level value statements + references still resolve |

After positional mapping is fixed, static column arrays still work; **query-driven** canonical programs additionally need array pluck and `Query(...)`.

---

## Appendix B: Source index

| Concern | Canonical path | Flutter path |
|---------|----------------|--------------|
| Spec | `openui/docs/content/docs/openui-lang/specification-v05.mdx` | [lang-reference.md](lang-reference.md) |
| Builtins | `packages/lang-core/src/parser/builtins.ts` | `packages/openui_core/lib/src/eval/builtins.dart` |
| Evaluator / pluck | `packages/lang-core/src/runtime/evaluator.ts` | `packages/openui_core/lib/src/eval/evaluator.dart` |
| Query manager | `packages/lang-core/src/runtime/queryManager.ts` | `packages/openui/lib/src/query_manager.dart` |
| Actions | `builtins.ts` `ACTION_STEPS` + renderer | `packages/openui_core/lib/src/actions/actions.dart` |
| Standard library | `packages/react-ui/src/genui-lib/openuiLibrary.tsx` | `packages/openui_components/lib/src/openui_library.dart` |
| Chat library | `packages/react-ui/src/genui-lib/openuiChatLibrary.tsx` | Removed (see CHANGELOG) |
| Serialize | `packages/lang-core/src/parser/serialize.ts` | — |
| @Query plan | — | [plan/2026-05-15-feat-at-query-builtin-plan.md](plan/2026-05-15-feat-at-query-builtin-plan.md) |

---

*Last updated against canonical openui at `/Users/marcustwichel/Developer/AI/openui` and openui_flutter v0.1.*
