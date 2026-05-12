import 'package:equatable/equatable.dart';

/// Sender role of a [UiMessage].
enum UiMessageRole {
  /// Submitted by the human via the input field.
  user,

  /// Streamed back from the LLM. Carries OpenUI Lang source.
  assistant,
}

/// A single entry in the live chat transcript.
///
/// Distinct from `dartantic_ai`'s `ChatMessage`, which is the on-the-wire
/// representation owned by [DartanticChatService](dartantic_chat_service.dart).
/// [UiMessage] is the UI projection consumed by `ChatBloc` and rendered by
/// `LlmChatScreen`.
class UiMessage extends Equatable {
  /// Creates a [UiMessage].
  const UiMessage({
    required this.id,
    required this.role,
    required this.text,
  });

  /// Stable identifier for the message. Used as a widget key in the
  /// transcript so streaming chunk updates don't replace the whole tile.
  final String id;

  /// Sender of the message.
  final UiMessageRole role;

  /// Plain text for user messages; OpenUI Lang source for assistant
  /// messages. Empty for an in-progress assistant turn before the first
  /// chunk arrives.
  final String text;

  /// Returns a copy with the given fields replaced.
  UiMessage copyWith({String? id, UiMessageRole? role, String? text}) {
    return UiMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
    );
  }

  @override
  List<Object?> get props => [id, role, text];
}
