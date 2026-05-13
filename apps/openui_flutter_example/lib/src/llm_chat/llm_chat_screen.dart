// The screen consumes openui / openui_components experimental types —
// the entire surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:dartantic_ai/dartantic_ai.dart' hide Tool;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/src/llm_chat/chat_bloc.dart';
import 'package:openui_flutter_example/src/llm_chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/snackbar_tool.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';
import 'package:openui_flutter_example/src/responsive.dart';

const _kDartDefineGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Factory signature for constructing the [LlmChatService] consumed by
/// [LlmChatScreen]. Defaults to `DartanticChatService.new`; tests inject
/// a fake.
typedef LlmChatServiceFactory = LlmChatService Function();

/// Top-level entry point for the Live destination of `AppShell`.
///
/// Owns the [ChatBloc] for the route. Tests pump [LlmChatView] directly
/// with a mocked bloc, or inject a fake [serviceFactory] to drive the
/// real wrapper without touching dartantic.
class LlmChatScreen extends StatefulWidget {
  /// Creates an [LlmChatScreen].
  const LlmChatScreen({
    super.key,
    this.onMenuTap,
    this.serviceFactory,
    this.dartDefineGeminiApiKey = _kDartDefineGeminiApiKey,
  });

  // Computed once at class load time so build() never regenerates it.

  static final String _systemPrompt = standardLibrary().prompt(
    examples: [
      // Send the user's choice back to the assistant when tapped.
      'root = Buttons(children: [Button(label: "Yes"), Button(label: "No")])',
    ],
  );

  /// Optional callback that opens the surrounding shell's drawer. Non-null
  /// only in narrow-viewport mode.
  final VoidCallback? onMenuTap;

  /// Optional factory for the underlying [LlmChatService]. Defaults to
  /// `DartanticChatService.new`. Provided for tests to inject fakes.
  final LlmChatServiceFactory? serviceFactory;

  /// API key from `--dart-define=GEMINI_API_KEY=...`.
  ///
  /// Defaults to [String.fromEnvironment] for production builds; tests can
  /// inject a value directly.
  final String dartDefineGeminiApiKey;

  // In-memory session key only. It is intentionally not persisted.
  static String _sessionGeminiApiKey = '';

  @override
  State<LlmChatScreen> createState() => _LlmChatScreenState();
}

class _LlmChatScreenState extends State<LlmChatScreen> {
  late final TextEditingController _apiKeyController;

  String get _effectiveGeminiApiKey {
    final sessionApiKey = LlmChatScreen._sessionGeminiApiKey.trim();
    if (sessionApiKey.isNotEmpty) return sessionApiKey;
    return widget.dartDefineGeminiApiKey.trim();
  }

  bool get _isUsingDartDefineApiKey =>
      LlmChatScreen._sessionGeminiApiKey.trim().isEmpty &&
      widget.dartDefineGeminiApiKey.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _submitApiKey() {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) return;
    setState(() {
      LlmChatScreen._sessionGeminiApiKey = apiKey;
      _apiKeyController.clear();
    });
  }

  void _clearApiKey() {
    setState(() {
      LlmChatScreen._sessionGeminiApiKey = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final factory =
        widget.serviceFactory ??
        () => DartanticChatService(systemPrompt: LlmChatScreen._systemPrompt);

    // Test-only override path: injected service can bypass API-key gating.
    if (widget.serviceFactory == null) {
      final apiKey = _effectiveGeminiApiKey;
      if (apiKey.isEmpty) {
        return _ApiKeyGate(
          onMenuTap: widget.onMenuTap,
          controller: _apiKeyController,
          onSubmit: _submitApiKey,
        );
      }
      Agent.providerFactories[kGeminiProvider] = () =>
          GoogleProvider(apiKey: apiKey);
    }
    return BlocProvider<ChatBloc>(
      key: ValueKey(_effectiveGeminiApiKey),
      create: (_) => ChatBloc(service: factory()),
      child: LlmChatView(
        onMenuTap: widget.onMenuTap,
        onChangeApiKey:
            widget.serviceFactory == null && !_isUsingDartDefineApiKey
            ? _clearApiKey
            : null,
        systemPrompt: LlmChatScreen._systemPrompt,
      ),
    );
  }
}

class _ApiKeyGate extends StatelessWidget {
  const _ApiKeyGate({
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

/// Pure view layer for the Live chat. Reads its [ChatBloc] from context.
///
/// Split out from [LlmChatScreen] so widget tests can pump the view
/// inside a `BlocProvider.value` with a mocked bloc.
class LlmChatView extends StatefulWidget {
  /// Creates an [LlmChatView].
  const LlmChatView({
    required this.systemPrompt,
    this.onMenuTap,
    this.onChangeApiKey,
    super.key,
  });

  /// Optional callback that opens the surrounding shell's drawer.
  final VoidCallback? onMenuTap;

  /// Optional callback invoked when the user wants to change the API key.
  final VoidCallback? onChangeApiKey;

  /// System prompt injected into the live chat service.
  final String systemPrompt;
  @override
  State<LlmChatView> createState() => _LlmChatViewState();
}

class _LlmChatViewState extends State<LlmChatView> {
  final Library<Widget> _library = standardLibrary().extend(
    tools: [
      SnackbarTool(),
    ],
  );
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
          if (widget.onChangeApiKey != null)
            IconButton(
              tooltip: 'Change API key',
              icon: const Icon(Icons.key),
              onPressed: widget.onChangeApiKey,
            ),

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
            systemPrompt: widget.systemPrompt,
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

class _RendererPane extends StatefulWidget {
  const _RendererPane({required this.library});

  final Library<Widget> library;

  @override
  State<_RendererPane> createState() => _RendererPaneState();
}

class _RendererPaneState extends State<_RendererPane> {
  String _lastParseableResponse = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final lastAssistant = state.messages
            .where((m) => m.role == UiMessageRole.assistant)
            .lastOrNull;
        final response = lastAssistant?.text ?? '';
        final isStreaming = state.status == ChatStatus.streaming;
        final rendererResponse = response.isNotEmpty
            ? response
            : (isStreaming ? '' : _lastParseableResponse);
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
                        onParseResult: (result) {
                          if (result.root != null &&
                              result.meta.errors.isEmpty) {
                            _lastParseableResponse = rendererResponse;
                          }
                        },
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
            Text(roleLabel, style: theme.textTheme.labelSmall),
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
