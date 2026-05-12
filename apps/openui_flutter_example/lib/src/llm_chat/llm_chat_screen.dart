// The screen consumes openui / openui_components experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/src/llm_chat/chat_bloc.dart';
import 'package:openui_flutter_example/src/llm_chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';
import 'package:openui_flutter_example/src/responsive.dart';

/// Factory signature for constructing the [LlmChatService] consumed by
/// [LlmChatScreen]. Defaults to `DartanticChatService.new`; tests inject
/// a fake.
typedef LlmChatServiceFactory = LlmChatService Function();

/// Top-level entry point for the Live destination of `AppShell`.
///
/// Owns the [ChatBloc] for the route. Tests pump [LlmChatView] directly
/// with a mocked bloc, or inject a fake [serviceFactory] to drive the
/// real wrapper without touching dartantic.
class LlmChatScreen extends StatelessWidget {
  /// Creates an [LlmChatScreen].
  const LlmChatScreen({super.key, this.onMenuTap, this.serviceFactory});

  // Computed once at class load time so build() never regenerates it.
  static final String _systemPrompt = openuiLibrary().prompt(
    const PromptOptions(),
  );

  /// Optional callback that opens the surrounding shell's drawer. Non-null
  /// only in narrow-viewport mode.
  final VoidCallback? onMenuTap;

  /// Optional factory for the underlying [LlmChatService]. Defaults to
  /// `DartanticChatService.new`. Provided for tests to inject fakes.
  final LlmChatServiceFactory? serviceFactory;

  @override
  Widget build(BuildContext context) {
    final factory =
        serviceFactory ??
        () => DartanticChatService(systemPrompt: _systemPrompt);
    return BlocProvider<ChatBloc>(
      create: (_) => ChatBloc(service: factory()),
      child: LlmChatView(onMenuTap: onMenuTap),
    );
  }
}

/// Pure view layer for the Live chat. Reads its [ChatBloc] from context.
///
/// Split out from [LlmChatScreen] so widget tests can pump the view
/// inside a `BlocProvider.value` with a mocked bloc.
class LlmChatView extends StatefulWidget {
  /// Creates an [LlmChatView].
  const LlmChatView({super.key, this.onMenuTap});

  /// Optional callback that opens the surrounding shell's drawer.
  final VoidCallback? onMenuTap;

  @override
  State<LlmChatView> createState() => _LlmChatViewState();
}

class _LlmChatViewState extends State<LlmChatView> {
  final Library<Widget> _library = openuiChatLibrary();
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(MessageSubmitted(text));
    _inputController.clear();
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
        title: const Text('Live'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.read<ChatBloc>().add(const ChatCleared()),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kWideBreakpoint;
          final renderer = _RendererPane(library: _library);
          final chat = _ChatPane(
            controller: _inputController,
            onSend: _send,
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: renderer),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: chat),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: renderer),
              const Divider(height: 1),
              SizedBox(height: 280, child: chat),
            ],
          );
        },
      ),
    );
  }
}

class _RendererPane extends StatelessWidget {
  const _RendererPane({required this.library});

  final Library<Widget> library;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final lastAssistant = state.messages
            .where((m) => m.role == UiMessageRole.assistant)
            .lastOrNull;
        final response = lastAssistant?.text ?? '';
        return Column(
          children: [
            Expanded(
              child: response.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ask the model to build something.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Renderer(
                        response: response,
                        isStreaming: state.status == ChatStatus.streaming,
                        library: library,
                      ),
                    ),
            ),
            const Divider(height: 1),
            _GeneratedCodeViewer(response: response),
          ],
        );
      },
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
      height: 200,
      width: double.infinity,
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

class _ChatPane extends StatelessWidget {
  const _ChatPane({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final isStreaming = state.status == ChatStatus.streaming;
        return Column(
          children: [
            Expanded(child: _Transcript(messages: state.messages)),
            if (state.status == ChatStatus.error)
              _ErrorBanner(message: state.error ?? 'Unknown error'),
            _InputBar(
              controller: controller,
              onSend: onSend,
              enabled: !isStreaming,
            ),
          ],
        );
      },
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.messages});

  final List<UiMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No messages yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    var assistantSeq = 0;
    final tiles = <Widget>[];
    for (final m in messages) {
      if (m.role == UiMessageRole.user) {
        tiles.add(_UserBubble(key: ValueKey(m.id), text: m.text));
      } else {
        assistantSeq++;
        tiles.add(
          _AssistantPlaceholder(key: ValueKey(m.id), index: assistantSeq),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: tiles,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(text),
      ),
    );
  }
}

class _AssistantPlaceholder extends StatelessWidget {
  const _AssistantPlaceholder({required this.index, super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_outlined, size: 16),
            const SizedBox(width: 8),
            Text('Generated UI #$index'),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.errorContainer,
      child: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: enabled ? (_) => onSend() : null,
              decoration: const InputDecoration(
                hintText: 'Describe a UI…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled ? onSend : null,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
