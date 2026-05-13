// The example app consumes openui / openui_core experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/src/scripts_chat/stub_llm.dart';

/// Enables the on-screen diagnostic panel and source viewer. Off by
/// default; flip with `flutter run --dart-define=DEBUG_PANEL=true`.
const bool kDebugPanel = bool.fromEnvironment('DEBUG_PANEL');

/// Streaming chat surface backed by the stub LLM.
///
/// Reached from the `Scripts` destination of the app shell. When the shell
/// is in narrow mode it passes [onMenuTap] so the AppBar's leading slot can
/// open the shell's drawer; in wide mode [onMenuTap] is null and no leading
/// is shown.
class ScriptsChatScreen extends StatefulWidget {
  /// Creates a [ScriptsChatScreen].
  const ScriptsChatScreen({super.key, this.onMenuTap});

  /// Optional callback that opens the surrounding shell's drawer. Non-null
  /// only in narrow-viewport mode.
  final VoidCallback? onMenuTap;

  @override
  State<ScriptsChatScreen> createState() => _ScriptsChatScreenState();
}

class _ScriptsChatScreenState extends State<ScriptsChatScreen> {
  late StubLlmService _service;
  late StubScript _active;
  final Library<Widget> _library = standardLibrary();
  final List<OpenUIError> _renderErrors = <OpenUIError>[];
  StreamSubscription<String>? _activePlayback;
  String _assistantResponse = '';
  bool _isStreaming = false;
  Object? _error;
  int _chunksReceived = 0;

  @override
  void initState() {
    super.initState();
    _active = kStubScripts.first;
    _service = StubLlmService(scriptPath: _active.assetPath);
  }

  @override
  void dispose() {
    unawaited(_activePlayback?.cancel());
    super.dispose();
  }

  Future<void> _play(StubScript script) async {
    await _activePlayback?.cancel();
    setState(() {
      _active = script;
      _service.scriptPath = script.assetPath;
      _renderErrors.clear();
      _assistantResponse = '';
      _isStreaming = true;
      _error = null;
      _chunksReceived = 0;
    });
    _activePlayback = _service.streamScript().listen(
      (delta) {
        if (!mounted) return;
        setState(() {
          _assistantResponse += delta;
          _chunksReceived += 1;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('script playback failed: $error\n$stackTrace');
        if (!mounted) return;
        setState(() {
          _error = error;
          _isStreaming = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isStreaming = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenuTap != null
            ? IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuTap,
              )
            : null,
        title: const Text('OpenUI Flutter'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kStubScripts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final script = kStubScripts[i];
                  final selected = script.assetPath == _active.assetPath;
                  return ChoiceChip(
                    label: Text(script.name),
                    selected: selected,
                    onSelected: (_) => unawaited(_play(script)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kDebugPanel) ...[
              _DiagnosticPanel(
                isRunning: _isStreaming,
                hasResponse: _assistantResponse.isNotEmpty,
                response: _assistantResponse,
                chunksReceived: _chunksReceived,
                error: _error,
                errors: _renderErrors,
              ),
              const SizedBox(height: 12),
            ],
            if (_assistantResponse.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Pick a script above to start streaming.'),
                ),
              )
            else ...[
              Renderer(
                response: _assistantResponse,
                isStreaming: _isStreaming,
                library: _library,
                onStateUpdate: (snapshot) {
                  debugPrint('onStateUpdate: $snapshot');
                },
                onAction: (event) {
                  debugPrint('onAction: $event');
                },
                onError: kDebugPanel
                    ? (errors) {
                        setState(() {
                          _renderErrors
                            ..clear()
                            ..addAll(errors);
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              _GeneratedCodeViewer(response: _assistantResponse),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticPanel extends StatelessWidget {
  const _DiagnosticPanel({
    required this.isRunning,
    required this.hasResponse,
    required this.response,
    required this.chunksReceived,
    required this.error,
    required this.errors,
  });

  final bool isRunning;
  final bool hasResponse;
  final String response;
  final int chunksReceived;
  final Object? error;
  final List<OpenUIError> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      'isRunning: $isRunning',
      'hasResponse: $hasResponse',
      'responseLen: ${response.length}',
      'chunksReceived: $chunksReceived',
      if (error != null) 'playback.error: $error',
      if (errors.isNotEmpty) 'renderErrors: ${errors.length}',
      for (final e in errors) '  • $e',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.bodySmall!.copyWith(fontFamily: 'monospace'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line)],
        ),
      ),
    );
  }
}

class _GeneratedCodeViewer extends StatelessWidget {
  const _GeneratedCodeViewer({required this.response});

  final String response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                'Generated OpenUI code',
                style: theme.textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  response.isEmpty
                      ? '// Generated OpenUI code will appear here.'
                      : response,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
