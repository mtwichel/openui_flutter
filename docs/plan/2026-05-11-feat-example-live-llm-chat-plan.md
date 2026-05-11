---
title: "feat: add live LLM chat to example app via dartantic + firebase"
type: feat
date: 2026-05-11
---

## feat: add live LLM chat to example app via dartantic + firebase — Standard

## Overview

Add a second chat surface to `apps/openui_flutter_example/` that talks to Gemini through `dartantic_ai` with a Firebase AI Logic (Vertex AI) backend, prompts the model to emit OpenUI Lang, and renders the streaming response live through the existing `Renderer` widget. All state — including chat history — is owned by a single `ChatBloc`. The example app's existing scripted-LLM demo stays put; both surfaces are reached from a new `AppShell` (NavigationRail on wide screens, Drawer on narrow). gh-pages safety is preserved via Firebase App Check + GCP API key restrictions.

Companion brainstorm: [`docs/brainstorm/2026-05-11-example-firebase-ai-chat-bloc-brainstorm-doc.md`](../brainstorm/2026-05-11-example-firebase-ai-chat-bloc-brainstorm-doc.md).

## Problem Statement / Motivation

`openui_flutter` v0.1 is feature-complete with five pre-recorded scripts proving the streaming-renderer pipeline. The published gh-pages demo is convincing but obviously stubbed — a visitor cannot type a prompt. A live LLM-backed surface closes that gap and validates the core claim of the project: an LLM streaming OpenUI Lang renders as native Flutter widgets in real time.

The brainstorm settled the major design questions over two refinement passes. This plan turns those decisions into an implementation path.

## Proposed Solution

A four-package-of-changes restructure of the example app:

1. **Top-level shell.** New `lib/src/shell/app_shell.dart` with a responsive `NavigationRail` (≥900 px) / `Drawer` (<900 px) hosting two destinations: `Scripts` and `Live`.
2. **Move existing demo under `scripts_chat/`.** Mechanical refactor — relocate `chat_screen.dart` and `stub_llm.dart` plus their tests, update imports. Behavior preserved exactly.
3. **New `llm_chat/` feature.** `ChatBloc` (single-source-of-truth state shape: in-progress assistant turn lives as the trailing `UiMessage`), `LlmChatService` interface + `DartanticChatService` impl wrapping `dartantic.Chat`, split-pane `LlmChatScreen` with `Renderer` on the left and transcript on the right.
4. **Bootstrap rewrite in `main.dart`.** Firebase init, App Check activation, `Agent.providerFactories` registration, then `runApp(AppShell())`.

### Backend selection: `firebase-vertex`, not `firebase-google`

Research at plan time resolved the brainstorm's open question. From `dartantic_firebase_ai`'s docs: "Vertex AI Backend for production... offers full integration with security features like App Check and Firebase Auth." App Check is Vertex AI only. Because the surface ships to the public gh-pages URL without flag-gating, App Check is non-negotiable, so the backend must be `firebase-vertex:gemini-2.5-flash`. This requires Firebase Blaze billing on the project — a prerequisite, not a code task.

### System prompt

Constant in `dartantic_chat_service.dart`. Inserts as the first entry of `Chat.history` via `ChatMessage.system(_openUiLangSystemPrompt)`. Contains:

- A short grammar primer derived from `docs/lang-reference.md` (sections: lexical structure, statement form, builtins, reactive props, action steps).
- Three few-shot examples — the literal contents of `01_hello.txt` (5 lines), `02_counter.txt` (9 lines), `04_form.txt` (13 lines).
- A strict format directive: respond with OpenUI Lang only — no code fences, no Markdown, no commentary.

Total prompt size estimate: ~120–150 lines, well under any model's context window.

## Technical Considerations

### Architecture

- The new code lives entirely under `apps/openui_flutter_example/`. No published package is modified. Per Decision D13 (layer boundary enforcement), nothing about the dependency graph changes.
- The `ChatBloc` does not use `OpenUiChatController`. `OpenUiChatController` is HTTP/SSE-shaped; `dartantic.Chat` is an SDK stream. Forcing the second through the first would invert the abstraction. Direct bloc-to-service wiring also satisfies the "Bloc owns chat history" requirement without double-bookkeeping.
- The bloc holds `List<UiMessage>` — a UI-only model with `role`, `text`, `id`. dartantic's own `ChatMessage` stays inside the service; the SDK never crosses out of `dartantic_chat_service.dart`.

### State shape (single source of truth)

```dart
class ChatState extends Equatable {
  final ChatStatus status;          // idle | streaming | error
  final List<UiMessage> messages;   // last entry during streaming = in-progress assistant turn
  final String? error;

  ChatState copyWith({ChatStatus? status, List<UiMessage>? messages, Object? error = _sentinel});
  @override List<Object?> get props => [status, messages, error];
  // Renderer derives inputs:
  //   response   = messages.lastWhereOrNull((m) => m.role == assistant)?.text ?? ''
  //   isStreaming = status == ChatStatus.streaming
}
```

### Events

Public events (user-facing):

- `MessageSubmitted(String text)` — submits a prompt.
- `ChatCleared()` — empties the transcript and resets the underlying `Chat`.

Private events (emitted from the stream subscription in the `MessageSubmitted` handler, leading underscore by convention):

- `_StreamChunkReceived(String chunk)` — appends to the trailing assistant `UiMessage.text`.
- `_StreamCompleted()` — flips `status: idle`.
- `_StreamFailed(Object error)` — removes the trailing assistant message, sets `error`, flips `status: error`.

### Service interface

```dart
abstract class LlmChatService {
  Stream<String> sendMessage(String text);
  void reset();
  Future<void> close();
}
```

`close()` is invoked from `ChatBloc.close()` so the bloc tears down the service when it is itself disposed by `BlocProvider`.

### Streaming flow

```
sendMessageStream(prompt)
  └─ Chat.sendStream(prompt)
       └─ for each chunk: yield chunk.output   // text delta
            └─ ChatBloc._StreamChunkReceived
                 └─ trailing assistant UiMessage.text += chunk
                      └─ Renderer.response rebuilds → StreamParser absorbs partial OpenUI Lang
```

The renderer's existing streaming-tolerant parser (autoclose pass on the pending tail, last-good-child error boundary) absorbs partial syntax mid-stream. No new parsing logic needed.

### Security

- `firebase-vertex:gemini-2.5-flash` requires Firebase Blaze (paid) billing.
- `FirebaseAppCheck.instance.activate(...)` runs before `runApp`. Provider config:
  - Web: `ReCaptchaEnterpriseProvider(<site-key>)`. The site key must be configured in the Firebase console and embedded as a `--dart-define` at build time.
  - Android: `AndroidProvider.playIntegrity`.
  - Apple: `AppleProvider.deviceCheck`.
- GCP API key restrictions (configured manually in the GCP console, not in code):
  - HTTP referrer allowlist: `mtwichel.github.io/openui_flutter/*` and `http://localhost:*` for dev.
  - Per-app-id restriction to the Firebase iOS/Android app IDs.
- The init order **must** fail closed: if `FirebaseAppCheck.instance.activate(...)` throws, the app should propagate the error rather than start with `runApp` and silently bypass App Check.

### Performance

- The system prompt adds a fixed ~120-line preamble to every turn. At Gemini 2.5 Flash pricing this is negligible (<$0.001 per turn at current rates) but worth noting.
- The bloc emits new state on every stream chunk. The screen's `BlocBuilder` rebuilds; the `Renderer` re-parses the (growing) buffer. The existing parser is incremental and handles this exact pattern already (the scripted demo streams at ~24-char chunk size; live LLM chunks are similar).
- No new dependencies on the published packages; their build/test surface is unchanged.

### Layer/dep impact

- `openui_flutter_example/pubspec.yaml` adds: `dartantic_ai`, `dartantic_firebase_ai`, `firebase_core`, `firebase_app_check`, `flutter_bloc`, `bloc`, `equatable`. `firebase_ai` is transitive via `dartantic_firebase_ai`.
- `melos.yaml` already excludes `openui_flutter_example` from `melos run test:flutter`. Example app tests run via `flutter test` from its directory. The new tests follow the same pattern.

## Prerequisites (one-time developer setup, not part of the code change)

These are required before the live demo can run but are not tasks the implementer ships in the PR. The README update (see Code Structure below) documents them for contributors.

- Firebase project upgraded to Blaze tier (Vertex AI requires billing).
- Vertex AI API enabled on the Firebase project's GCP project.
- reCAPTCHA Enterprise site key created in the Firebase console for the gh-pages origin.
- App Check enforcement enabled for the Vertex AI API in the Firebase console.
- GCP API key restrictions configured: HTTP referrer allowlist (`mtwichel.github.io/openui_flutter/*` and `http://localhost:*`) + per-app-id restriction.
- GCP daily quota cap on the Vertex AI API key (cost-DoS belt-and-suspenders beyond App Check).
- `flutterfire configure` run; `apps/openui_flutter_example/lib/firebase_options.dart` generated.

## Acceptance Criteria

### Functional

- [ ] App boots into `AppShell`. Default destination: `Scripts` (existing demo).
- [ ] `NavigationRail` visible at ≥900 px viewport; `Drawer` visible at <900 px.
- [ ] `Scripts` destination shows the existing five-script demo with no behavioral change.
- [ ] `Live` destination shows a split-pane layout: left = `Renderer`, right = chat transcript + input.
- [ ] At ≥900 px: `Renderer` and transcript are side-by-side with a `VerticalDivider`.
- [ ] At <900 px: `Renderer` is on top, transcript below, with a `Divider`.
- [ ] Typing a prompt + pressing send streams a Gemini response. The `Renderer` paints widgets live as chunks arrive.
- [ ] The send button is disabled while `status == streaming`.
- [ ] The transcript right pane shows user message bubbles and compact "Generated UI #N" placeholder rows for each completed assistant turn.
- [ ] A "Clear" affordance (icon button in the screen's AppBar) empties the transcript, blanks the left pane, and resets the underlying `dartantic.Chat`.
- [ ] On stream error: the in-progress assistant placeholder is removed, an error banner appears above the input, and the left pane reverts to the previous completed assistant turn (or empty if first turn).
- [ ] Submitting a second message after a successful first turn preserves the first turn's `Chat` history on the wire (the model gets multi-turn context).

### Code structure

- [ ] `apps/openui_flutter_example/lib/main.dart`: rewritten init order — `WidgetsFlutterBinding.ensureInitialized` → `Firebase.initializeApp(options:)` → `FirebaseAppCheck.instance.activate(...)` → `Agent.providerFactories['firebase-vertex'] = () => FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI)` → `runApp(AppShell())`.
- [ ] `apps/openui_flutter_example/lib/src/shell/app_shell.dart`: responsive `AppShell` with `NavigationRail` / `Drawer`.
- [ ] `apps/openui_flutter_example/lib/src/scripts_chat/chat_screen.dart`: moved from `lib/src/chat_screen.dart`, imports updated.
- [ ] `apps/openui_flutter_example/lib/src/scripts_chat/stub_llm.dart`: moved from `lib/src/stub_llm.dart`, imports updated.
- [ ] `apps/openui_flutter_example/lib/src/llm_chat/ui_message.dart`: `UiMessage` with `Equatable`, `id` + `role` + `text`, plus `copyWith` and `props`.
- [ ] `apps/openui_flutter_example/lib/src/llm_chat/llm_chat_service.dart`: `abstract class LlmChatService { Stream<String> sendMessage(String text); void reset(); Future<void> close(); }`.
- [ ] `apps/openui_flutter_example/lib/src/llm_chat/dartantic_chat_service.dart`: `DartanticChatService implements LlmChatService` wrapping `dartantic.Chat`. Holds the system prompt constant. `close()` releases any held resources.
- [ ] `apps/openui_flutter_example/lib/src/llm_chat/chat_bloc.dart`: `ChatBloc` with `ChatState` (including `copyWith` and `props`), public events `MessageSubmitted` + `ChatCleared`, private events `_StreamChunkReceived` + `_StreamCompleted` + `_StreamFailed`. Overrides `close()` to call `service.close()`.
- [ ] `apps/openui_flutter_example/lib/src/llm_chat/llm_chat_screen.dart`: `BlocProvider`-scoped split-pane screen with `LayoutBuilder` for the 900 px breakpoint.
- [ ] `apps/openui_flutter_example/README.md` updated with the Prerequisites section (Firebase Blaze, Vertex AI enable, App Check setup, GCP key restrictions, quota cap, `flutterfire configure`) and the required `--dart-define`s for the reCAPTCHA Enterprise site key.
- [ ] All public symbols carry dartdoc comments (project convention).

### Testing

- [ ] `apps/openui_flutter_example/test/src/llm_chat/chat_bloc_test.dart`: `bloc_test` suite. Use a hand-rolled fake `LlmChatService` backed by a `StreamController<String>` so tests can drive chunks, completion, and error in sequence and assert on subscription cancellation. Covers:
  - happy-path single turn (user → streaming → completed; trailing assistant message accumulates chunks)
  - multi-turn (history grows correctly across two `MessageSubmitted` events)
  - mid-stream error (trailing assistant message removed; status = error; prior turn preserved; error string surfaced)
  - clear-while-streaming (fake service's `StreamController` is closed by the bloc cancelling the subscription; `service.reset()` called; status idle)
  - clear-while-idle (messages emptied; service.reset called)
  - `bloc.close()` invokes `service.close()`.
- [ ] `apps/openui_flutter_example/test/src/llm_chat/llm_chat_screen_test.dart`: widget test with `MockBloc` from `bloc_test`. Use `whenListen(bloc, Stream<ChatState>.fromIterable([...]), initialState: ...)` to seed state sequences. Covers:
  - input enabled when idle, disabled while streaming
  - error banner visible on error state
  - transcript renders user prompts and assistant placeholders in submission order
  - the wrapped `Renderer` receives the last assistant message's text and the streaming flag
  - tap on "Clear" dispatches `ChatCleared`
  - the `Library` is mocked so the widget tree doesn't need real components
  - viewport 1200×800: side-by-side layout (Renderer left, transcript right with `VerticalDivider`).
  - viewport 600×800: stacked layout (Renderer on top, transcript below, with `Divider`).
- [ ] `apps/openui_flutter_example/test/src/llm_chat/dartantic_chat_service_test.dart`: behavior test against a fake `dartantic.Chat` injected via constructor. Asserts: chunks from the fake's `sendStream` are forwarded verbatim into the service's output `Stream<String>`; an error from the fake surfaces as a `Stream.error`; `reset()` rebuilds the inner `Chat` (verified by the fake's construction count); `close()` releases resources. No real network call. (`UiMessage` equality + `copyWith` are exercised by the bloc tests above — no dedicated test file.)
- [ ] `apps/openui_flutter_example/test/src/shell/app_shell_test.dart`: navigation between `Scripts` and `Live` destinations.
- [ ] `apps/openui_flutter_example/test/widget_test.dart`: updated to assert the `AppShell` boots and `Scripts` is the default destination.
- [ ] `apps/openui_flutter_example/test/src/scripts_chat/stub_llm_test.dart`: moved from `test/src/stub_llm_test.dart`, import updated. Behavior unchanged.
- [ ] All tests pass under `flutter test` from `apps/openui_flutter_example/`.

### Hygiene

- [ ] `cd apps/openui_flutter_example && flutter analyze --fatal-infos` passes.
- [ ] `dart format --set-exit-if-changed apps/openui_flutter_example/` passes.
- [ ] `melos run analyze:flutter` passes repo-wide.
- [ ] README of the example app updated with the setup steps (App Check, billing, `--dart-define`s).
- [ ] No new entries to publishable packages' CHANGELOGs (the example app is private, no CHANGELOG required).

## Success Metrics

- Visitor on gh-pages can navigate to `Live`, type a prompt, see Gemini stream OpenUI Lang, watch widgets paint live. Abuse attempts from non-allowed origins are blocked at the Firebase App Check layer (`403 Forbidden` from the Vertex AI endpoint).
- A new contributor can clone the repo, follow the README's setup section, and have the live demo running locally within ~15 minutes (mostly waiting on `flutterfire configure` and Firebase console clicks).
- All existing example app behavior (the five scripted scenarios) remains pixel-identical post-restructure.

## Dependencies & Risks

### New dependencies

| Package | Version constraint | Why |
|---|---|---|
| `dartantic_ai` | latest | `Agent`, `Chat`, `ChatMessage`, `sendStream` |
| `dartantic_firebase_ai` | latest | `FirebaseAIProvider` + `FirebaseAIBackend.vertexAI` |
| `firebase_core` | latest | `Firebase.initializeApp` |
| `firebase_app_check` | latest | App Check activation |
| `flutter_bloc` | latest | `BlocProvider`, `BlocBuilder` |
| `bloc` | latest | base `Bloc` class |
| `equatable` | latest | value semantics on state and `UiMessage` |
| `bloc_test` (dev) | latest | bloc unit tests + `MockBloc` |

Versions pinned at implementation time. The project's existing pin style (`^x.y.z`) applies.

### Risks

- **Billing.** Vertex AI requires Firebase Blaze. The repo owner needs to either fund this or move the live demo behind a `LIVE_CHAT` build flag and rebuild the gh-pages without it — reversing the brainstorm decision. Flagged here so it's a deliberate accept rather than a discovery during build.
- **App Check parity on web is reCAPTCHA Enterprise, which is paid.** The free tier has rate limits but is sufficient for a demo. If costs become a concern, switch to `ReCaptchaV3Provider` (free, weaker).
- **System prompt drift.** Gemini may emit prose, Markdown, or code fences despite the instruction. The renderer's last-good-child boundary masks this — the visible widgets don't change. Detection / banner is deferred (open question in brainstorm). Worst case at v1: a turn does nothing visible from the user's perspective.
- **dartantic version churn.** dartantic_ai is a young package. The API may shift between versions. Mitigation: pin tight version constraints; the `LlmChatService` interface insulates the bloc from SDK changes.
- **Restructure scope creep.** Moving `chat_screen.dart` and `stub_llm.dart` under `scripts_chat/` touches imports across tests and `main.dart`. Mechanical but invasive. Mitigation: a pre-flight commit that only does the rename + import updates, before the new feature lands — see "Implementation order" below.

### Implementation order

A suggested sequencing that keeps each step reviewable:

1. **Move existing chat surface to `scripts_chat/`** (no behavior change). Update `main.dart` to keep referencing the moved class. Run tests; commit. This is a pure mechanical refactor PR-candidate.
2. **Add the empty `AppShell` with one destination** (Scripts only). `main.dart` now wraps the existing screen in the shell. Tests for navigation can stub the second destination as a placeholder.
3. **Add new dependencies + Firebase initialization** in `main.dart`. No new UI yet; the init runs but nothing consumes it. App still boots into Scripts.
4. **Add `UiMessage` + `LlmChatService` interface + `DartanticChatService`.** No bloc or screen yet. `DartanticChatService` is unit-tested against a fake `dartantic.Chat` (chunk forwarding, error mapping, `reset()` rebuilds, `close()` releases).
5. **Add `ChatBloc` + bloc tests.** No screen yet.
6. **Add `LlmChatScreen` + widget tests.** Wire it as the second `AppShell` destination.
7. **Update README** with setup steps. Final pass of `melos run analyze:flutter` and `flutter test`.

Steps 1–2 are the mechanical-refactor portion and could land as a separate PR if reviewers prefer; steps 3–7 are the live-chat feature. The brainstorm doesn't pre-commit to splitting; defer to plan-technical-review and to the reviewer.

## References & Research

### Brainstorm

- [`docs/brainstorm/2026-05-11-example-firebase-ai-chat-bloc-brainstorm-doc.md`](../brainstorm/2026-05-11-example-firebase-ai-chat-bloc-brainstorm-doc.md) — design decisions, rejected alternatives, open questions.

### In-repo context

- `apps/openui_flutter_example/lib/main.dart` — current boot path; will be rewritten.
- `apps/openui_flutter_example/lib/src/chat_screen.dart:99` — `StreamBuilder<ChatState>` pattern that the new bloc replaces (and reference for the scripted-chat screen post-move).
- `apps/openui_flutter_example/lib/src/stub_llm.dart` — exemplifies the `clientFactory`-style abstraction; will be moved unchanged.
- `apps/openui_flutter_example/test/src/stub_llm_test.dart` — adapter-driven test pattern; the new service smoke test follows the same shape.
- `apps/openui_flutter_example/assets/scripts/01_hello.txt`, `02_counter.txt`, `04_form.txt` — pinned few-shot examples for the system prompt.
- `docs/lang-reference.md` — source for the system prompt's grammar primer (sections 1–4: lexical, grammar, builtins, reactive props).
- `docs/architecture.md:95` — confirms `openui_chat` ships no state-management binding; the example app is the right place to demonstrate Bloc.
- `docs/decisions/2026-05-10-phase0-decisions.md` D13 — layer boundary enforcement; not impacted (all new code is in the application layer).
- `melos.yaml` — `openui_flutter_example` is excluded from `melos run test:flutter`; example app tests run via `flutter test` directly.

### External

- `dartantic_ai` / `dartantic_firebase_ai` — [pub.dev/packages/dartantic_ai](https://pub.dev/packages/dartantic_ai), [github.com/csells/dartantic](https://github.com/csells/dartantic). Confirmed: App Check is Vertex AI only.
- Firebase App Check Flutter — [firebase.google.com/docs/app-check/flutter/default-providers](https://firebase.google.com/docs/app-check/flutter/default-providers). `FirebaseAppCheck.instance.activate(webProvider:, androidProvider:, appleProvider:)`.
- Firebase AI Logic production checklist — [firebase.google.com/docs/ai-logic/production-checklist](https://firebase.google.com/docs/ai-logic/production-checklist). App Check + limited-use tokens.
- `flutter_bloc` patterns — VGV `vgv-ai-flutter-plugin:bloc` skill should be consulted during implementation for event handler shape and test conventions.

### Open from brainstorm (now resolved)

- ~~App Check parity on `firebase-google`~~ — resolved: must use `firebase-vertex`.
- ~~`firebase_ai` `systemInstruction` API surface~~ — moot; dartantic uses `ChatMessage.system(...)` in history.
