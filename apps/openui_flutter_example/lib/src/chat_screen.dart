// The example app consumes openui_chat / openui experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_chat/openui_chat.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';

import 'package:openui_flutter_example/src/stub_llm.dart';

/// Streaming chat surface backed by the stub LLM.
class ChatScreen extends StatefulWidget {
  /// Creates a [ChatScreen].
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late StubLlmService _service;
  late OpenUiChatController _controller;
  late StubScript _active;
  final Library<Widget> _library = openuiChatLibrary();

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
    });
    await _controller.sendMessage('Run ${script.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          if (state.messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Pick a script above to start streaming.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final assistant = state.messages
              .whereType<AssistantMessage>()
              .lastOrNull;
          if (assistant == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Renderer(
              response: assistant.response,
              isStreaming: assistant.isStreaming,
              library: _library,
            ),
          );
        },
      ),
    );
  }
}
