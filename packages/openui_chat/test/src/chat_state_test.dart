import 'package:openui_chat/openui_chat.dart';
import 'package:test/test.dart';

void main() {
  group('ChatState', () {
    test('initial is idle with empty message list', () {
      expect(ChatState.initial.messages, isEmpty);
      expect(ChatState.initial.isRunning, isFalse);
      expect(ChatState.initial.error, isNull);
      expect(ChatState.initial.threadId, isNull);
    });

    test('messages list is unmodifiable', () {
      final state = ChatState(messages: <Message>[UserMessage(content: 'hi')]);
      expect(
        () => state.messages.add(UserMessage(content: 'x')),
        throwsUnsupportedError,
      );
    });

    test('copyWith overrides only the provided fields', () {
      final ts = DateTime(2026);
      final base = ChatState(
        messages: <Message>[UserMessage(content: 'a', createdAt: ts)],
        threadId: 't',
      );
      final next = base.copyWith(isRunning: true);
      expect(next.messages, base.messages);
      expect(next.threadId, 't');
      expect(next.isRunning, isTrue);
    });

    test('copyWith clearError replaces a non-null error with null', () {
      final base = ChatState(error: 'oops');
      expect(base.copyWith(clearError: true).error, isNull);
    });

    test('equality is structural', () {
      final ts = DateTime(2026);
      final a = ChatState(
        messages: <Message>[UserMessage(content: 'x', id: '1', createdAt: ts)],
      );
      final b = ChatState(
        messages: <Message>[UserMessage(content: 'x', id: '1', createdAt: ts)],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
