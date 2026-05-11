// The example app consumes openui_chat / openui experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_chat/openui_chat.dart';
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
  late OpenUiChatController _controller;
  late StubScript _active;
  final Library<Widget> _library = openuiChatLibrary();
  final List<OpenUIError> _renderErrors = <OpenUIError>[];
  bool _showSource = false;

  @override
  void initState() {
    super.initState();
    _active = kStubScripts.first;
    _service = StubLlmService(scriptPath: _active.assetPath);
    _controller = buildStubChatController(service: _service);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play(StubScript script) async {
    setState(() {
      _active = script;
      _service.scriptPath = script.assetPath;
      _renderErrors.clear();
    });
    try {
      await _controller.sendMessage('Run ${script.name}');
    } on Object catch (error, stackTrace) {
      debugPrint('sendMessage failed: $error\n$stackTrace');
      if (mounted) setState(() {});
    }
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
        actions: [
          if (kDebugPanel)
            IconButton(
              tooltip: _showSource ? 'Hide source' : 'Show source',
              icon: Icon(_showSource ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showSource = !_showSource),
            ),
        ],
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
                    onSelected: (_) => _play(script),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<ChatState>(
        stream: _controller.stateStream,
        initialData: _controller.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _controller.currentState;
          final assistant = state.messages
              .whereType<AssistantMessage>()
              .lastOrNull;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kDebugPanel) ...[
                  _DiagnosticPanel(
                    state: state,
                    assistant: assistant,
                    errors: _renderErrors,
                  ),
                  const SizedBox(height: 12),
                ],
                if (assistant == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Pick a script above to start streaming.'),
                    ),
                  )
                else ...[
                  if (kDebugPanel && _showSource)
                    _SourcePanel(response: assistant.response),
                  Renderer(
                    response: assistant.response,
                    isStreaming: assistant.isStreaming,
                    library: _library,
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
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiagnosticPanel extends StatelessWidget {
  const _DiagnosticPanel({
    required this.state,
    required this.assistant,
    required this.errors,
  });

  final ChatState state;
  final AssistantMessage? assistant;
  final List<OpenUIError> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      'isRunning: ${state.isRunning}',
      'messages: ${state.messages.length}',
      if (assistant != null) ...[
        'assistant.streaming: ${assistant!.isStreaming}',
        'assistant.responseLen: ${assistant!.response.length}',
      ],
      if (state.error != null) 'state.error: ${state.error}',
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

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({required this.response});

  final String response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: SelectableText(
          response.isEmpty ? '(no response yet)' : response,
          style: theme.textTheme.bodySmall!.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
