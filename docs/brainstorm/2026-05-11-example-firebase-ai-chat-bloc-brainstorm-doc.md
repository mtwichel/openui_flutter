---
date: 2026-05-11
topic: example-firebase-ai-chat-bloc
---

# LLM Chat (Bloc-Owned, OpenUI-Lang Rendering) in the Example App

## What We're Building

A second chat surface inside `apps/openui_flutter_example/` that talks to a real LLM through the `dartantic_ai` package with a Firebase AI Logic backend (via `dartantic_firebase_ai`). Gemini is prompted to emit **OpenUI Lang** as its response text. Each chunk appends to the in-progress assistant message in the bloc, and the screen drives the existing `Renderer` widget with that message's text and `openuiChatLibrary()`. The screen is split-pane: the live `Renderer` paints widgets on the left, a chat transcript on the right.

All state — message history (with the in-progress assistant turn modeled as an entry in the list), status, errors — is owned by a single locally-scoped `ChatBloc`. No persistence, no auth, no tool calling. The existing scripted-LLM demo stays put; the example app gains a top-level shell with two surfaces (`Scripts` and `Live`) reached from a `NavigationRail` (wide) or `Drawer` (narrow).

The dartantic-with-Firebase combo is chosen so the app keeps Firebase App Check as its abuse-mitigation lever for the public gh-pages deploy, while gaining dartantic's cleaner `Agent` / `Chat` / `ChatMessage` API. dartantic remains provider-portable: swapping to `google` (raw Gemini API), `openai`, or others later is a one-line agent string change.

## Why This Approach

Three approaches were considered.

**ChatBloc drives the Renderer directly (chosen).** New `lib/src/llm_chat/` with a Bloc, a `LlmChatService` interface, a `DartanticChatService` implementation that wraps a dartantic `Chat`, and a split-pane screen. The Bloc holds the message list; the in-progress assistant turn is itself an entry in that list whose text grows chunk-by-chunk. The chat surface does not go through `OpenUiChatController` — that controller is HTTP/SSE-shaped and dartantic is an SDK stream; the Bloc replaces the controller for this surface.

- Pros: cleanest match to the user's spec ("local Bloc owns everything"). Reuses `Renderer` and `openuiChatLibrary()` exactly as the existing demo does. Hits the project's marquee demo: LLM streams OpenUI Lang and it paints live. dartantic's `Chat` helper handles on-the-wire history; the bloc handles UI projection.
- Cons: requires a system-prompt strategy to keep Gemini emitting OpenUI Lang only; invalid output still renders (the renderer's error boundary holds the last-good child) but the experience degrades if the prompt drifts.

**Wire dartantic into the existing `OpenUiChatController` via a new adapter.** Build an SDK-stream-to-`StreamProtocolAdapter` shim so dartantic looks like another SSE backend behind the existing controller.

- Pros: would let the new screen reuse the controller's action-dispatch wiring (`@ToAssistant`, `@Set`, etc.) for free.
- Cons: requires fabricating fake `http.StreamedResponse`s for an SDK that has no HTTP shape — an inversion, not a fit. Also doesn't match the user's "controlled locally by a bloc, including chat history" spec, since `OpenUiChatController` owns history itself. Defer until there's a real second consumer of a non-HTTP adapter.

**Plain text chat (no Renderer).** Render assistant output as text bubbles, ignore OpenUI Lang.

- Pros: minimum surface area; no prompt engineering.
- Cons: rejected by user — defeats the purpose of demoing this inside an OpenUI app.

## Key Decisions

### Scope and surface

- **Two top-level surfaces, navigated via `NavigationRail` / `Drawer`.** Wrap the app in an `AppShell` that holds the rail (wide screens) or a drawer (narrow). Destinations: `Scripts` (existing scripted demo) and `Live` (new). **Why:** the user picked tab/drawer with both. `NavigationRail` reads natively on web/desktop where the split-pane needs horizontal real estate; the drawer is the mobile fallback. Standard responsive Material pattern, no custom shell needed.
- **Split-pane on the `Live` screen.** Left: `Renderer(response: <last assistant message text>, isStreaming: state.status == streaming, library: openuiChatLibrary())`. Right: chat transcript — user message bubbles, plus compact assistant-turn placeholders ("Generated UI #N"). The most recent assistant turn is what the left pane renders; older turns are not revisitable in v1. **Why:** clean separation between "what the LLM said" (left, rendered) and "the conversation so far" (right, scrollable history).
- **Responsive layout switch.** Use `LayoutBuilder`: at >900 px wide, render side-by-side with a `VerticalDivider`; below 900 px, stack vertically (renderer on top, chat below) with a `Divider`. **Why:** the example app runs on web (gh-pages), desktop, and mobile; one breakpoint covers all three.
- **Plain text only on the right pane.** User prompts as bubbles. Assistant turns shown as small placeholder rows, not raw OpenUI Lang source. A debug toggle (mirrors `kDebugPanel`) can reveal the raw source per turn. **Why:** dumping OpenUI Lang source into the transcript is noisy and undermines the "the rendering IS the response" framing.
- **No persistence.** History lives in `ChatBloc` state, dies with the route. **Why:** matches the user's "in-memory only" call.
- **No tool calling, no function declarations, no cancellation.** Send button disabled while `status != idle`. **Why:** matches the user's "disable send while streaming" call. Each is a real new surface; defer until there's a concrete need.

### Architecture

- **`flutter_bloc` for state.** Add `flutter_bloc`, `bloc`, `equatable` to `apps/openui_flutter_example/pubspec.yaml`. **Why:** VGV default; example app is the right place to show it. The published packages stay Bloc-free per D4.
- **`ChatBloc` directly drives `Renderer`, not via `OpenUiChatController`.** The Bloc emits state on every chunk; the screen rebuilds `Renderer` with the trailing assistant message's text. **Why:** `OpenUiChatController` is HTTP/SSE-shaped, doesn't fit dartantic's SDK stream, and would duplicate history with the Bloc. Direct wiring is the simpler shape for "Bloc owns everything."
- **Service interface, not direct dartantic use from the Bloc.** Define `abstract class LlmChatService { Stream<String> sendMessage(String text); void reset(); }` returning a stream of text deltas. `DartanticChatService` implements it by owning a `Chat` instance and mapping `chunk.output` from `chat.sendStream(text)` into its own stream. **Why:** keeps the Bloc trivially testable with a fake service; the SDK never crosses out of the service.
- **`Chat` helper for transport, not raw `Agent.sendStream`.** dartantic's `Chat` auto-manages on-the-wire history so the service doesn't have to. The service holds one `Chat`; `reset()` rebuilds it with just the system message. **Why:** less code, no manual `history.addAll(chunk.messages)` bookkeeping.
- **Two history projections, one source of truth per consumer.** `Chat` (inside the service) holds on-the-wire history. `ChatBloc` holds on-screen history (`List<UiMessage>`, with the in-progress assistant entry as the trailing item during streaming). On `ChatCleared`, the Bloc empties its list and calls `service.reset()`, which replaces the `Chat`. **Why:** the bloc projection has UI-only fields; coupling to dartantic's `ChatMessage` would leak the SDK across the codebase.
- **`UiMessage` is the bloc's own UI model.** Distinct type from dartantic's `ChatMessage`. Carries `role` (user|assistant), `text` (raw text for user; OpenUI Lang source for assistant), and an `id`. **Why:** the bloc and screen are SDK-agnostic; the mapping lives inside the service.
- **Firebase backend via `dartantic_firebase_ai`, `firebase-google` provider, Gemini 2.5 Flash.** Initialize: `await Firebase.initializeApp(); Agent.providerFactories['firebase-google'] = () => FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);`. Service constructs `Chat(Agent('firebase-google:gemini-2.5-flash'), history: [ChatMessage.system(_openUiLangSystemPrompt)])`. **Why:** Firebase under the hood preserves App Check as an abuse-mitigation lever; dartantic on top gives a cleaner API and provider portability. Switchable to `firebase-vertex` (paid, App Check-confirmed) or `google` (raw Gemini API, no Firebase) later by string change.
- **Firebase App Check enabled + GCP key restrictions.** Required because the `Live` surface ships to the public gh-pages URL without a flag-gate. App Check uses the web reCAPTCHA Enterprise provider, initialized via `FirebaseAppCheck.instance.activate(...)` before `runApp`. API keys are constrained in the Google Cloud console with per-app-id and HTTP-referrer restrictions (gh-pages origin + localhost for dev). **Why:** unauthenticated chat against unconstrained keys from the public web URL is unacceptable. App Check + key restrictions are the minimum baseline before merge.
- **No Firebase Auth in MVP.** Anonymous, no sign-in flow. App Check is the abuse control. **Why:** the example app demos OpenUI rendering, not user accounts; sign-in would be a separate brainstorm.

### System prompt

- **Tight, OpenUI-Lang-only system prompt.** Provided as `ChatMessage.system(_openUiLangSystemPrompt)` — the first entry in `Chat.history`. Tells Gemini: respond with OpenUI Lang only — no code fences, no commentary, no Markdown. Embed a grammar primer derived from `docs/lang-reference.md` and three few-shot examples: `01_hello.txt`, `02_counter.txt`, and `04_form.txt` from `assets/scripts/` (smallest, most representative; cover text rendering, reactive state, and form binding respectively). **Why:** the renderer has no robustness to prose preambles or code-fenced responses; keeping the model in-format is cheaper than parsing around its drift. The three pinned scripts give the model concrete pattern coverage without bloating the context window.
- **The system prompt lives in a constant in `dartantic_chat_service.dart`.** Not in an asset, not in a separate config file. **Why:** v1 — keep it visible and one-edit-away.
- **No retry / no clean-up.** If Gemini emits prose or a code fence anyway, the renderer's last-good-child error boundary keeps the previous rendering visible (or shows empty on first-turn drift). The malformed text is still stored in the trailing assistant message; the placeholder row shows in the transcript. **Why:** simplest behavior that doesn't blank the screen on a model misstep. Better recovery (detect parse-empty, surface a banner) is a follow-up.

### Bloc shape

Single source of truth: the in-progress assistant turn is itself a `UiMessage` inside the `messages` list. Chunks mutate that message's text in place (via copyWith on emit). The screen derives Renderer inputs from `messages` + `status`.

State (single class, `Equatable`):

- `status: ChatStatus` — `idle`, `streaming`, `error`.
- `messages: List<UiMessage>` — UI history. `UiMessage` carries `role` (user|assistant), `text` (raw text for user; OpenUI Lang source for assistant), and an `id`. When `status == streaming`, the last entry is an assistant message whose text is the partial buffer.
- `error: String?` — last error, cleared on the next successful submit.

The screen reads `Renderer.response` from `messages.lastWhereOrNull((m) => m.role == assistant)?.text ?? ''` and `Renderer.isStreaming` from `status == ChatStatus.streaming`. No separate top-level buffer field.

Events:

- `MessageSubmitted(String text)` — public. Appends a user `UiMessage` and a fresh empty assistant `UiMessage`, sets `status: streaming`, opens the service stream, dispatches internal chunk events.
- `_StreamChunkReceived(String chunk)` — internal. Replaces the trailing assistant message with a copy whose text is `old.text + chunk`. The renderer re-parses on every state change (its existing streaming-tolerant behavior absorbs partial syntax mid-stream).
- `_StreamCompleted()` — internal. Sets `status: idle`. The trailing assistant message is already in place; no buffer to flush, no re-emit gymnastics.
- `_StreamErrored(Object error)` — internal. Stores `error`, removes the trailing (in-progress) assistant message, sets `status: error`. The screen's `lastWhereOrNull` selector falls back to the prior completed assistant turn if one exists, or empty otherwise.
- `ChatCleared()` — public. Empties messages, clears `error`, sets `status: idle`, calls `service.reset()`. Left pane goes blank.

Internal events are emitted from the stream subscription opened in the `MessageSubmitted` handler. The handler `await`s the stream so the Bloc emits one final state when the stream completes.

### Dependencies and initialization

- **New deps in the example app's `pubspec.yaml`:** `dartantic_ai`, `dartantic_firebase_ai`, `firebase_core`, `firebase_app_check`, `flutter_bloc`, `bloc`, `equatable`. **Why:** `dartantic_ai` for the `Agent` / `Chat` / `ChatMessage` surface; `dartantic_firebase_ai` for the Firebase backend bridge; `firebase_core` for `Firebase.initializeApp`; `firebase_app_check` for abuse mitigation; `flutter_bloc` + `bloc` + `equatable` for the Bloc story. The `firebase_ai` package comes in transitively via `dartantic_firebase_ai` — no direct import.
- **`main.dart` initialization order:** `WidgetsFlutterBinding.ensureInitialized()` → `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` → `FirebaseAppCheck.instance.activate(webProvider: ReCaptchaEnterpriseProvider(...), androidProvider: AndroidProvider.playIntegrity, appleProvider: AppleProvider.deviceCheck)` → `Agent.providerFactories['firebase-google'] = () => FirebaseAIProvider(backend: FirebaseAIBackend.googleAI)` → `runApp(AppShell())`. Requires a `firebase_options.dart` generated by `flutterfire configure`. Setup is a one-time developer task documented in the README — not part of the implementation work.
- **No build-flag gating.** Per user choice, the `Live` surface is always visible. Abuse risk on gh-pages is mitigated by the App Check + key-restriction decision above, not by hiding the surface.

### Testing

- **Bloc unit tests with `bloc_test` and a fake `LlmChatService`.** Cover: happy-path stream (user → streaming → assistant message in history), mid-stream error (partial buffer dropped, last-good text restored), clear-while-streaming (cancels the subscription and `service.reset()`), multi-turn (history grows correctly).
- **Widget test for `LlmChatScreen` driven by a fake `ChatBloc`** (`MockBloc` from `bloc_test`). Verify: input enabled when idle, disabled while streaming, error banner visible on error state, transcript renders user prompts and assistant placeholders in order, the `Renderer` receives the last assistant message's text and the streaming flag. Mock the `Library` so the widget tree doesn't need real components.
- **Responsive layout test.** Widget test at >900 and <900 viewport widths to confirm the side-by-side / stacked switch.
- **No live-Firebase tests.** `DartanticChatService` gets a thin smoke test that verifies stream shape; actual SDK call path isn't exercised in CI. The published packages remain Firebase- and dartantic-free.

### Layout

```
apps/openui_flutter_example/lib/
  main.dart                     // Firebase + App Check init, agent factory registration, runApp(AppShell)
  firebase_options.dart         // generated by `flutterfire configure`
  src/
    shell/
      app_shell.dart            // NavigationRail / Drawer, two destinations
    scripts_chat/               // moved from src/ root
      chat_screen.dart          // renamed from src/chat_screen.dart
      stub_llm.dart             // moved from src/stub_llm.dart
    llm_chat/
      llm_chat_screen.dart      // split-pane: Renderer + transcript
      chat_bloc.dart            // bloc + events + state
      ui_message.dart           // bloc's own UI model (not dartantic.ChatMessage)
      llm_chat_service.dart     // abstract interface
      dartantic_chat_service.dart    // concrete (dartantic.Chat + system prompt constant)

apps/openui_flutter_example/test/src/
  shell/app_shell_test.dart
  llm_chat/chat_bloc_test.dart
  llm_chat/llm_chat_screen_test.dart
  scripts_chat/...              // existing tests moved
```

This is a moderate restructure of the example app — the existing single-screen layout becomes a shell with two destinations. Existing tests move but don't change in substance.

## Open Questions

- **App Check parity on the `firebase-google` backend.** `dartantic_firebase_ai`'s docs call out App Check + Auth integration specifically on the Vertex AI path. Whether `firebase-google` (the free googleAI backend) honors `FirebaseAppCheck.instance` at parity needs a 5-minute verification at plan time. **If not**, switch the backend to `firebase-vertex` (paid, App Check-confirmed). The decision changes the billing model but not the bloc shape.
- **Past-rendering revisitability.** v1 left pane only shows the latest assistant turn. Tapping older placeholders to re-render their source is an obvious follow-up but adds bloc state (a "selected turn" pointer) and isn't on the v1 critical path.
- **System-prompt drift.** No automated check that Gemini actually emits OpenUI Lang. The renderer's error boundary masks failures silently — the user sees "nothing changed" rather than a meaningful error. Worth a follow-up to detect parse-empty results and surface a banner.
- **Cancel button.** Deferred per user choice. The Bloc will already hold the `StreamSubscription` (needed for `ChatCleared`), so adding cancel later is a 5-line change — not a structural concern.
- **Token / chunk count UI.** Deferred. Cheap to add later under a debug flag.
- **History length cap.** Bloc holds unbounded history. Not a v1 concern; worth a cap before any real deployment.
