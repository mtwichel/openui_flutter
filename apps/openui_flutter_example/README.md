# openui_flutter_example

Private demo app for the OpenUI Flutter port. Two surfaces, switched via a
`NavigationRail` (wide screens) or `Drawer` (narrow):

- **Scripts** — five pre-recorded OpenUI Lang programs streamed through the
  full controller + renderer pipeline. No real LLM call. Runs out of the
  box.
- **Live** — real Gemini chat through `dartantic_ai` with a Firebase AI
  Logic (Vertex AI) backend. Asks the model to emit OpenUI Lang and
  renders it live as widgets. Requires the live-chat setup below.

The Scripts surface is the gh-pages demo. The Live surface ships in the
same bundle but only works when the Firebase project is configured.

## Running the Scripts demo

```bash
melos bootstrap
cd apps/openui_flutter_example
flutter run --dart-define=DEBUG_PANEL=true  # optional debug toggles
```

The first frame shows the Scripts destination by default — pick a chip and
watch the OpenUI Lang stream and render.

## Live chat setup

The Live destination requires a Firebase project on the Blaze (pay-as-you-go)
tier with Vertex AI enabled. App Check is non-negotiable because the example
app publishes to a public URL.

1. **Create a Firebase project** at [console.firebase.google.com](https://console.firebase.google.com).
   Upgrade to Blaze billing (Vertex AI requires it).
2. **Enable Vertex AI API** in the linked GCP project. The dartantic
   `firebase-vertex` backend talks to the Vertex AI endpoint via the
   Firebase AI Logic SDK.
3. **Set up App Check.** This is what stops random visitors from running
   up your bill.
   - In the Firebase console: AppCheck → register your web/iOS/Android apps.
   - Web: create a reCAPTCHA Enterprise site key restricted to your
     gh-pages origin (and `localhost` for local dev).
   - Enable App Check enforcement for the Vertex AI API.
4. **Restrict the GCP API keys.** In the Google Cloud console:
   - HTTP referrer allowlist: `mtwichel.github.io/openui_flutter/*` plus
     `http://localhost:*` for development.
   - Per-app-id restrictions to your registered Firebase app IDs.
5. **Set a daily quota cap** on the Vertex AI API key. Belt-and-suspenders
   beyond App Check for cost-DoS protection.
6. **Generate `firebase_options.dart`:**

   ```bash
   dart pub global activate flutterfire_cli
   cd apps/openui_flutter_example
   flutterfire configure
   ```

   This overwrites the placeholder `lib/firebase_options.dart`. Commit the
   generated file.
7. **Run with the reCAPTCHA site key injected at build time:**

   ```bash
   flutter run -d chrome \
     --dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<your-site-key>
   ```

   On mobile (iOS/Android) the default Apple/Play Integrity providers kick
   in automatically — no extra `--dart-define` needed.

If you skip these steps and run the app, the Scripts surface still works.
The Live surface will fail at `Firebase.initializeApp(...)` because the
placeholder `firebase_options.dart` carries stub values.

## What lives where

```
lib/
  main.dart                       boot + Firebase + App Check
  firebase_options.dart           generated; placeholder in the repo
  src/
    shell/app_shell.dart          NavigationRail / Drawer responsive shell
    scripts_chat/                 the pre-recorded demo (existing)
    llm_chat/
      llm_chat_screen.dart        split-pane: Renderer + transcript
      chat_bloc.dart              ChatBloc + ChatState + events
      ui_message.dart             UI projection of a transcript entry
      llm_chat_service.dart       abstract chat service
      dartantic_chat_service.dart concrete service + system prompt
```

## Tests

```bash
cd apps/openui_flutter_example
flutter test
```

`openui_flutter_example` is intentionally excluded from
`melos run test:flutter` (see `melos.yaml`) — the example app's tests run
directly with `flutter test`. No real Firebase or network call is
exercised in CI; the bloc tests use a hand-rolled fake `LlmChatService`
and the screen tests use a mocked `ChatBloc`.
