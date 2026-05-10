import 'package:flutter/material.dart';

void main() => runApp(const OpenUIExampleApp());

/// Phase 0 scaffold for the example app.
///
/// The full streaming-chat demo (stubbed LLM, five reference scripts,
/// integration test) lands in Phase 4 of the port.
class OpenUIExampleApp extends StatelessWidget {
  /// Creates the example app.
  const OpenUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI Flutter Example',
      theme: ThemeData(useMaterial3: true),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenUI Flutter')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Phase 0 scaffold. Streaming chat demo lands in a later PR.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
