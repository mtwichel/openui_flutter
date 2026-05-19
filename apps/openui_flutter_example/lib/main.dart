import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:openui_flutter_example/chat/chat.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return ShadApp.custom(
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: ShadColorScheme.fromName('violet'),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: ShadColorScheme.fromName(
          'violet',
          brightness: Brightness.dark,
        ),
      ),
      appBuilder: (context) {
        return MaterialApp(
          title: 'OpenUI Flutter',
          theme: Theme.of(context),
          home: const ChatPage(),
          builder: (context, child) {
            return ShadAppBuilder(child: child);
          },
        );
      },
    );
  }
}
