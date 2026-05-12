import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:openui_flutter_example/firebase_options.dart';
import 'package:openui_flutter_example/src/llm_chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/src/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check is disabled for the demo. Re-enable before publishing —
    // without it, the Vertex AI key shipped in `firebase_options.dart`
    // has no abuse protection beyond GCP API-key referrer / quota caps.
    Agent.providerFactories[kFirebaseVertexProvider] = () =>
        FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
  } on Object catch (error, stackTrace) {
    // Firebase init failed. The Scripts destination of `AppShell` does
    // not depend on Firebase and still works; the Live destination will
    // surface this error if the user navigates to it.
    debugPrint(
      'Live chat unavailable — Firebase init failed.\n'
      'See apps/openui_flutter_example/README.md "Live chat setup".\n'
      'Error: $error\n$stackTrace',
    );
  }
  runApp(const OpenUIExampleApp());
}

/// Boots the streaming-chat demo.
class OpenUIExampleApp extends StatelessWidget {
  /// Creates the example app.
  const OpenUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI Flutter',
      theme: ThemeData(useMaterial3: true),
      home: const AppShell(),
    );
  }
}
