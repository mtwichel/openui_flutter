import 'package:flutter/material.dart';

import 'package:openui_flutter_example/src/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
