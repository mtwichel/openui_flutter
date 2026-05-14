import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/chat/bloc/chat_bloc.dart';
import 'package:openui_flutter_example/chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/chat/snackbar_tool.dart';
import 'package:openui_flutter_example/chat/view/chat_view.dart';

final Library<Widget> _chatOpenUiLibrary = standardLibrary().extend(
  tools: [
    SnackbarTool(),
  ],
);
final String _chatSystemPrompt = _chatOpenUiLibrary.prompt();

/// Live chat route: provides [ChatBloc] and builds [ChatView].
class ChatPage extends StatelessWidget {
  /// Creates a [ChatPage].
  const ChatPage({
    super.key,
    this.onMenuTap,
    this.chatServiceFactory,
    this.dartDefineGeminiApiKey = const String.fromEnvironment(
      'GEMINI_API_KEY',
    ),
  });

  /// Optional callback that opens the surrounding shell's drawer.
  final VoidCallback? onMenuTap;

  /// Optional factory for tests; skips Gemini key gating when non-null.
  final DartanticChatService Function()? chatServiceFactory;

  /// Value for `--dart-define=GEMINI_API_KEY=...` (overridable in tests).
  final String dartDefineGeminiApiKey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatBloc(
        service:
            chatServiceFactory?.call() ??
            DartanticChatService(systemPrompt: _chatSystemPrompt),
        dartDefineGeminiApiKey: dartDefineGeminiApiKey,
        skipGeminiAuth: chatServiceFactory != null,
      ),
      child: ChatView(
        library: _chatOpenUiLibrary,
        systemPrompt: _chatSystemPrompt,
        onMenuTap: onMenuTap,
      ),
    );
  }
}
