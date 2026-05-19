# openui_flutter_example

Private demo app for the OpenUI Flutter port. A single **live chat** surface:
Gemini (via `dartantic_ai`) streams OpenUI Lang; `Renderer` + `standardLibrary()`
turn it into shadcn-styled widgets in real time.

## Running locally

```bash
melos bootstrap
cd apps/openui_flutter_example
flutter run --dart-define=GEMINI_API_KEY=<your-gemini-api-key>
```

Without `GEMINI_API_KEY`, the app opens but shows a **Gemini API key** gate. You
can paste a key in the UI for that session only (see below).

Optional debug panels (generated OpenUI source, store snapshot, action log) are
available on wide layouts when the chat is active.

## Gemini API key

Two ways to authenticate:

1. **Build-time** — pass `--dart-define=GEMINI_API_KEY=...` when running or
   building. `main.dart` registers the `google` dartantic provider factory.
2. **In-app (session only)** — paste a key on the gate screen. The key is kept
   **only in RAM** for the running process: it is not written to disk, local
   storage, or any server, and is cleared when the app restarts or the session
   is reset.

## How it is wired

- **Theme** — `ShadApp` + violet color scheme in `main.dart` (required for
  `openui_components` shadcn widgets).
- **Library** — `standardLibrary().extend(...)` in `chat/view/chat_page.dart`
  adds DummyJSON product tools plus a local `snackbar` tool.
- **System prompt** — `_chatOpenUiLibrary.prompt()` so the model sees the same
  component and tool catalog the renderer registers.
- **State** — `ChatBloc` accumulates LLM text deltas and passes cumulative
  `response` + `isStreaming` into `Renderer`.

```
lib/
  main.dart                 ShadApp + optional GEMINI_API_KEY dart-define
  responsive.dart           wide vs narrow layout breakpoints
  chat/
    bloc/                   ChatBloc, transcript + renderer side effects
    dartantic_chat_service.dart   Gemini streaming + debug logging
    tools.dart              SnackbarTool, FetchProductsTool, FetchProductTool
    view/
      chat_page.dart        BlocProvider + library + system prompt
      chat_view.dart        key gate, Renderer, transcript, debug panels
```

`assets/scripts/` remains in the repo as reference OpenUI Lang fixtures; the
current UI does not replay them.

## Tests

```bash
cd apps/openui_flutter_example
flutter test
```

`openui_flutter_example` is intentionally excluded from `melos run test:flutter`
(see `melos.yaml`). Tests use a fake `DartanticChatService` and mocked
`ChatBloc` — no real Gemini calls in CI.
