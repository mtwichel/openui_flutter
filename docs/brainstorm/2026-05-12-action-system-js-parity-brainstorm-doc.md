---
date: 2026-05-12
topic: action-system-js-parity
---

# Action System: JS Reference Parity

## What We're Building

Rework the action system in `openui_core` and `openui` so it matches the OpenUI JS reference at https://www.openui.com/docs/openui-lang/interactivity. The existing Dart implementation parses and executes the same five step kinds (`@Set`, `@Reset`, `@Run`, `@ToAssistant`, `@OpenUrl`) but diverges from the JS contract on dispatch shape, host-callback granularity, the component-author trigger API, implicit Button behavior, and custom action types.

The result is a single host-facing `Renderer.onAction` that fires a JS-shaped `ActionEvent` per host-routed step, an internal pipeline that handles `@Set`/`@Reset`/`@Run` without bubbling to the host, a `RendererScope.triggerAction` seam for component authors, and an open `ActionEvent.type` to support custom action types. This is a fully breaking rewrite of the experimental v0.1 surface.

## Why This Approach

Three approaches considered:

1. **Additive shim (rejected)**: keep the existing `dispatchAction` + `onAction(plan)` surface and add a new `triggerAction` path on top. Easy migration, but leaves two action models in the package and locks in the divergent `ActionEvent { plan, statementId, payload }` shape forever. The point of the work is contract parity, so a parallel API defeats it.

2. **Reshape in place (rejected)**: keep names like `Renderer.onAction` and `dispatchAction` but change their payloads and behavior. Cheaper to migrate, but `dispatchAction`'s three host callbacks (`onRun`, `onContinueConversation`, `onOpenUrl`) are the wrong factoring — JS keeps `@Run` internal and unifies the rest under one `onAction` stream. Trying to keep the signature pushes the contract drift downstream.

3. **Clean rewrite (chosen)**: delete `dispatchAction`'s per-callback signature, fold `@Run` into the renderer's `QueryManager`, rebuild `ActionEvent` to the JS shape (`type`, `params`, `humanFriendlyMessage`, `formState`, `formName`), expose `RendererScope.triggerAction` as the component-author API, and bump the experimental version. The package is pre-1.0 with everything `@experimental`, so the cost of breaking is contained. Doing it once and cleanly is cheaper than two incremental migrations.

## Key Decisions

- **Full JS parity, breaking rewrite.** `ActionEvent` is reshaped to `{ type, params, humanFriendlyMessage, formState, formName }`. The old `{ plan, statementId, payload }` is deleted. Rationale: pre-1.0 and `@experimental`, no production callers to preserve. A clean break is cheaper than a parallel migration.

- **`@Run` becomes internal.** `dispatchAction` no longer takes `onRun`. The renderer dispatches `@Run` directly to its `QueryManager` (`invalidate` for queries, mutation runner with halt-on-failure for mutations). Rationale: matches JS, removes a host-side responsibility, and the halt-on-mutation-failure semantics are easier to enforce when the runtime owns the call.

- **One host callback: `Renderer.onAction`.** Fires once per host-routed step (`@ToAssistant` → `continue_conversation`, `@OpenUrl` → `open_url`, and any custom type). `@Set` and `@Reset` are silent — they only mutate the store. Rationale: matches JS granularity and lets host apps switch on `event.type` cleanly.

- **`ActionEvent.type` is an open string; custom types come from component code, not the lang parser.** Built-in values come from a `BuiltinActionType` enum (`continueConversation`, `openUrl`), and `type` is typed as `String` so non-built-in types pass through. The parser stays closed (still only the five known step kinds). Custom types reach the host when a component constructs an `ActionPlan` in Dart with a step that carries a custom `type` and passes it to `triggerAction`. Rationale: matches the JS contract in practice — the JS lang parser is also closed; only the host event type is open. Keeps the parser surface minimal and avoids ambiguity with future built-ins.

- **`RendererScope.triggerAction(userMessage, {formName, action})`** is the component-author API. Replaces `onActionAst`. The current AST-level seam is too low-level for component authors and leaks parser types into the component package. Rationale: matches `useTriggerAction` in JS and keeps the `InheritedWidget` lookup pattern already used elsewhere in the package.

- **Typed `FormState` payload (deviation).** Instead of `Map<String, Object?>`, expose a small immutable `FormState` class on `ActionEvent.formState` with `Object? get(String name)` and `Map<String, Object?> toMap()`. Rationale: friendlier Dart ergonomics without changing what's in it. JS docs describe it as `Record<string, any>`; the Dart equivalent of a record is a typed value object. The map is still reachable via `.toMap()` for parity.

- **Implicit `@ToAssistant(label)` for Buttons without `onClick`.** The Button component (and any other component with a default action) calls `triggerAction(label)` with no explicit plan, which the renderer routes to `onAction({type: continueConversation, humanFriendlyMessage: label, ...})`. Rationale: matches the JS spec line "Buttons without an explicit Action prop automatically send their label to the assistant."

- **Unchanged from existing implementation.** `@Reset` default resolution from `result.meta.stateDecls` (skip-with-error on missing default, other steps continue), and the `onStateUpdate` / `initialState` surface on `Renderer`. Rationale: already match the JS contract — leave as-is.

## Scope Notes

- **QueryManager mutation support is a prerequisite.** The current `_queryManager` in `openui/lib/src/renderer.dart` only exposes `invalidate(id, args)`. JS calls `queryManager.fireMutation(statementId, evaluatedArgs)` and halts the action plan if it returns falsy. Folding `@Run` internal means adding a mutation runner with halt-on-failure to the Dart `QueryManager` before the action rewrite lands, or in the same change. Not a tiny addition — the planner should size it explicitly.

- **Cross-package consumer audit.** The migration touches every consumer of the current `ActionEvent` and `dispatchAction`. Known surface to inventory before planning:
  - `openui/lib/src/renderer.dart` (`onAction`, `_dispatch`).
  - `openui_components/lib/src/components/` (Button, Form, and any other component reaching into `RendererScope.onActionAst`).
  - `openui_chat`, `openui_mcp`, and `apps/` example app — any wiring of `Renderer.onAction` or import of `ActionEvent` / `dispatchAction` from `openui_core` or `openui`.
  - Tests under `openui_core/test/src/actions/` and `openui/test/src/`.

## Open Questions

- **Mutation failure surfacing.** With `@Run` internal, how does the host learn a mutation failed? Options: (a) `Renderer.onError` already covers it via `OpenUIError`; (b) emit a synthetic `ActionEvent` with a known type like `mutation_failed`; (c) silent — only the UI's error rendering shows it. JS appears to halt the plan silently and rely on `onError`. Resolve in planning.

- **`triggerAction` payload for non-plan calls.** JS's third arg accepts either a full `ActionPlan` or a legacy `{type, params}` config. Should the Dart `triggerAction` accept both, or only `ActionPlan` plus an inferred default? Recommend Dart-only: `ActionPlan?` and let custom-type emitters pass a single-step plan with a string `type` field. Confirm in planning.

- **Where does `BuiltinActionType` live?** `openui_core` exports `ActionPlan` and step types today. The enum is a stable contract — it belongs next to `ActionEvent`, which currently lives in `openui` (the Flutter package). Decide whether `ActionEvent` moves to `openui_core` so non-Flutter consumers can adopt the type, or stays Flutter-only. Lean: move both to `openui_core` since they're framework-agnostic.

- **Component-to-trigger wiring.** Today the Button path in `renderer.dart:482-497` synthesizes a `VoidCallback` when an `onClick` prop's AST is action-shaped, closing over `_dispatch(value, statementId)`. The new path closes over `triggerAction(label, formName, plan)` instead. Confirm during planning that the prop-evaluation step still happens in `_resolvePropValue` (so the callback carries the parsed `ActionPlan` and the resolved label), rather than pushed down into each component.

- **Implicit-action label sources.** For Button the implicit label is the `label` prop. What about other components that might want an implicit `@ToAssistant`? Recommend keeping it Button-specific in v1 and adding case-by-case if the JS reference adds more.
