// The screen consumes openui / openui_components experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/chat/chat.dart';
import 'package:openui_flutter_example/responsive.dart';

const _kGeneratedOpenUICodePanelHeaderKey = ValueKey<String>(
  'generated-openui-code-panel-header',
);
const _kStoreInspectorPanelHeaderKey = ValueKey<String>(
  'store-inspector-panel-header',
);
const _kActionLogPanelHeaderKey = ValueKey<String>(
  'action-log-panel-header',
);

Object? _jsonEncodable(Object? value) {
  if (value == null || value is num || value is String || value is bool) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic k, dynamic v) => MapEntry(k.toString(), _jsonEncodable(v)),
    );
  }
  if (value is Iterable) {
    return value.map(_jsonEncodable).toList();
  }
  return value.toString();
}

String _formatStoreSnapshot(Map<String, Object?> snapshot) {
  if (snapshot.isEmpty) {
    return '// No store keys yet.';
  }
  final encoded = _jsonEncodable(snapshot);
  return const JsonEncoder.withIndent('  ').convert(encoded);
}

String _formatLogTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _formatActionLog(List<OpenUiActionLogEntry> entries) {
  if (entries.isEmpty) {
    return '// No actions logged yet.';
  }
  const encoder = JsonEncoder.withIndent('  ');
  final buf = StringBuffer();
  for (final e in entries) {
    buf.writeln('[${_formatLogTime(e.loggedAt)}] ${e.type}');
    final msg = e.humanFriendlyMessage;
    if (msg != null && msg.isNotEmpty) {
      buf.writeln('  message: $msg');
    }
    if (e.params.isNotEmpty) {
      buf.writeln('  params:');
      buf.writeln(encoder.convert(_jsonEncodable(e.params)));
    }
    buf.writeln();
  }
  return buf.toString().trimRight();
}

Future<void> _copyTextToClipboard(
  BuildContext context,
  String text,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}

/// Live chat UI: Gemini key gate when [ChatState.geminiConfigured] is false,
/// otherwise renderer + transcript. Expects [ChatBloc] above this widget.
class ChatView extends StatefulWidget {
  /// Creates a [ChatView].
  const ChatView({
    required this.library,
    required this.systemPrompt,
    this.onMenuTap,
    super.key,
  });

  /// OpenUI component library for the renderer.
  final Library<Widget> library;

  /// Optional callback that opens the surrounding shell's drawer.
  final VoidCallback? onMenuTap;

  /// System prompt shown in the transcript header.
  final String systemPrompt;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _inputController = TextEditingController();
  late final TextEditingController _geminiApiKeyController;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(MessageSubmitted(text));
    _inputController.clear();
  }

  void _submitGeminiApiKey() {
    context.read<ChatBloc>().add(
      GeminiApiKeySubmitted(_geminiApiKeyController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          !previous.geminiConfigured && current.geminiConfigured,
      listener: (context, state) {
        _geminiApiKeyController.clear();
      },
      builder: (context, state) {
        if (!state.geminiConfigured) {
          return _GeminiApiKeyGate(
            onMenuTap: widget.onMenuTap,
            controller: _geminiApiKeyController,
            onSubmit: _submitGeminiApiKey,
          );
        }
        return _LiveChatScaffold(
          library: widget.library,
          systemPrompt: widget.systemPrompt,
          onMenuTap: widget.onMenuTap,
          inputController: _inputController,
          onSend: _send,
        );
      },
    );
  }
}

/// Split renderer + transcript chrome when Gemini is configured.
class _LiveChatScaffold extends StatelessWidget {
  const _LiveChatScaffold({
    required this.library,
    required this.systemPrompt,
    required this.inputController,
    required this.onSend,
    this.onMenuTap,
  });

  final Library<Widget> library;
  final String systemPrompt;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: onMenuTap != null
                ? IconButton(
                    tooltip: 'Open menu',
                    icon: const Icon(Icons.menu),
                    onPressed: onMenuTap,
                  )
                : null,
            title: const Text('Live'),
            actions: [
              if (state.sessionKeyActive)
                IconButton(
                  tooltip: 'Change API key',
                  icon: const Icon(Icons.key),
                  onPressed: () => context.read<ChatBloc>().add(
                    const GeminiSessionApiKeyCleared(),
                  ),
                ),
              IconButton(
                tooltip: 'Clear chat',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    context.read<ChatBloc>().add(const ChatCleared()),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kWideBreakpoint;
              final renderer = _RendererPane(library: library);
              final chat = _ChatPane(
                controller: inputController,
                onSend: onSend,
                systemPrompt: systemPrompt,
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
      },
    );
  }
}

class _GeminiApiKeyGate extends StatelessWidget {
  const _GeminiApiKeyGate({
    required this.onMenuTap,
    required this.controller,
    required this.onSubmit,
  });

  final VoidCallback? onMenuTap;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onMenuTap != null
            ? IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu),
                onPressed: onMenuTap,
              )
            : null,
        title: const Text('Live'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter Gemini API key',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Needed to enable Live chat for this session only. '
                  'The key is kept in memory and resets when the app restarts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    hintText: 'AIza...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onSubmit,
                  child: const Text('Enable Live chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RendererPane extends StatefulWidget {
  const _RendererPane({required this.library});

  final Library<Widget> library;

  @override
  State<_RendererPane> createState() => _RendererPaneState();
}

class _RendererPaneState extends State<_RendererPane> {
  String _lastParseableResponse = '';

  void _maybeClearRendererSidePanels(
    BuildContext context,
    String rendererResponse,
  ) {
    if (rendererResponse.isNotEmpty) return;
    final bloc = context.read<ChatBloc>();
    if (bloc.state.renderStoreSnapshot.isEmpty &&
        bloc.state.actionLog.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final b = context.read<ChatBloc>();
      if (b.state.renderStoreSnapshot.isNotEmpty) {
        b.add(const RenderStoreSnapshotUpdated(<String, Object?>{}));
      }
      if (b.state.actionLog.isNotEmpty) {
        b.add(const OpenUiActionLogCleared());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final lastAssistant = state.messages
            .where((m) => m.role == UiMessageRole.assistant)
            .lastOrNull;
        final hasAssistantResponse = lastAssistant != null;
        final response = lastAssistant?.text ?? '';
        final isStreaming = state.status == ChatStatus.streaming;
        final rendererResponse = response.isNotEmpty
            ? response
            : (isStreaming || !hasAssistantResponse
                  ? ''
                  : _lastParseableResponse);
        _maybeClearRendererSidePanels(context, rendererResponse);
        final theme = Theme.of(context);
        return Column(
          children: [
            Expanded(
              child: rendererResponse.isEmpty
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
                        response: rendererResponse,
                        isStreaming: isStreaming,
                        library: widget.library,
                        onAction: (event) {
                          context.read<ChatBloc>().add(
                            OpenUiHostActionLogged(
                              OpenUiActionLogEntry.fromActionEvent(
                                event,
                                loggedAt: DateTime.now(),
                              ),
                            ),
                          );
                          if (event.type ==
                              BuiltinActionType.continueConversation) {
                            final trimmed = (event.humanFriendlyMessage ?? '')
                                .trim();
                            if (trimmed.isEmpty) return;
                            context.read<ChatBloc>().add(
                              MessageSubmitted(trimmed),
                            );
                          }
                        },
                        onParseResult: (result) {
                          if (result.root != null &&
                              result.meta.errors.isEmpty) {
                            _lastParseableResponse = rendererResponse;
                          }
                        },
                        onStateUpdate: (snapshot) {
                          context.read<ChatBloc>().add(
                            RenderStoreSnapshotUpdated(
                              Map<String, Object?>.from(snapshot),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const Divider(height: 1),
            _CollapsibleDebugPanel(
              headerKey: _kGeneratedOpenUICodePanelHeaderKey,
              title: 'Generated OpenUI code',
              textToCopy: response.isEmpty
                  ? '// Generated OpenUI code will appear here.'
                  : response,
              expanded: state.isGeneratedOpenUiCodePanelExpanded,
              onExpansionChanged: (expanded) {
                context.read<ChatBloc>().add(
                  LlmDebugPanelExpansionChanged(
                    panel: LlmDebugPanel.generatedOpenUiCode,
                    expanded: expanded,
                  ),
                );
              },
              expandedChild: SingleChildScrollView(
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
            const Divider(height: 1),
            _CollapsibleDebugPanel(
              headerKey: _kStoreInspectorPanelHeaderKey,
              title: 'Store inspector',
              textToCopy: _formatStoreSnapshot(state.renderStoreSnapshot),
              expanded: state.isStoreInspectorPanelExpanded,
              onExpansionChanged: (expanded) {
                context.read<ChatBloc>().add(
                  LlmDebugPanelExpansionChanged(
                    panel: LlmDebugPanel.storeInspector,
                    expanded: expanded,
                  ),
                );
              },
              expandedChild: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _formatStoreSnapshot(state.renderStoreSnapshot),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _CollapsibleDebugPanel(
              headerKey: _kActionLogPanelHeaderKey,
              title: 'Action log',
              textToCopy: _formatActionLog(state.actionLog),
              expanded: state.isActionLogPanelExpanded,
              onExpansionChanged: (expanded) {
                context.read<ChatBloc>().add(
                  LlmDebugPanelExpansionChanged(
                    panel: LlmDebugPanel.actionLog,
                    expanded: expanded,
                  ),
                );
              },
              expandedChild: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _formatActionLog(state.actionLog),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollapsibleDebugPanel extends StatelessWidget {
  const _CollapsibleDebugPanel({
    required this.headerKey,
    required this.title,
    required this.textToCopy,
    required this.expanded,
    required this.onExpansionChanged,
    required this.expandedChild,
  });

  final Key headerKey;
  final String title;
  final String textToCopy;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget expandedChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: headerKey,
                      onTap: () => onExpansionChanged(!expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await _copyTextToClipboard(context, textToCopy);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: expandedChild,
            ),
        ],
      ),
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.controller,
    required this.onSend,
    required this.systemPrompt,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String systemPrompt;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final isStreaming = state.status == ChatStatus.streaming;
        return Column(
          children: [
            Expanded(
              child: _Transcript(
                messages: state.messages,
                systemPrompt: systemPrompt,
              ),
            ),
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
  const _Transcript({
    required this.messages,
    required this.systemPrompt,
  });

  final List<UiMessage> messages;
  final String systemPrompt;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _CopyableMessageBubble(
        key: const ValueKey('system-prompt'),
        roleLabel: 'System',
        text: systemPrompt,
        alignment: Alignment.center,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
      ),
    ];

    for (final message in messages) {
      final roleLabel = switch (message.role) {
        UiMessageRole.user => 'User',
        UiMessageRole.assistant => 'Assistant',
        UiMessageRole.thinking => 'Thinking',
        UiMessageRole.tool => 'Tool',
      };
      final alignment = switch (message.role) {
        UiMessageRole.user => Alignment.centerRight,
        UiMessageRole.assistant ||
        UiMessageRole.thinking ||
        UiMessageRole.tool => Alignment.centerLeft,
      };
      final background = switch (message.role) {
        UiMessageRole.user => Theme.of(context).colorScheme.primaryContainer,
        UiMessageRole.assistant => Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        UiMessageRole.thinking =>
          Theme.of(context).colorScheme.secondaryContainer.withValues(
            alpha: 0.65,
          ),
        UiMessageRole.tool =>
          Theme.of(context).colorScheme.tertiaryContainer.withValues(
            alpha: 0.65,
          ),
      };
      tiles.add(
        _CopyableMessageBubble(
          key: ValueKey(message.id),
          roleLabel: roleLabel,
          text: message.text,
          alignment: alignment,
          backgroundColor: background,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: tiles,
    );
  }
}

class _CopyableMessageBubble extends StatelessWidget {
  const _CopyableMessageBubble({
    required this.roleLabel,
    required this.text,
    required this.alignment,
    required this.backgroundColor,
    super.key,
  });

  final String roleLabel;
  final String text;
  final Alignment alignment;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(roleLabel, style: theme.textTheme.labelSmall),
                ),
                IconButton(
                  tooltip: 'Copy $roleLabel message',
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await _copyTextToClipboard(
                      context,
                      text.isEmpty ? '(streaming...)' : text,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(text.isEmpty ? '(streaming...)' : text),
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

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed &&
            widget.enabled) {
          widget.onSend();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Describe a UI…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: FilledButton(
              onPressed: widget.enabled ? widget.onSend : null,
              child: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
