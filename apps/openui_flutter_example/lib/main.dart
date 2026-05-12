import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';

import 'package:openui_flutter_example/src/llm_chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/src/shell/app_shell.dart';

const _kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_kGeminiApiKey.isNotEmpty) {
    Agent.providerFactories[kGeminiProvider] = () =>
        GoogleProvider(apiKey: _kGeminiApiKey);
  } else {
    debugPrint(
      'Live chat unavailable'
      ' — missing --dart-define=GEMINI_API_KEY=<your-key>.',
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
