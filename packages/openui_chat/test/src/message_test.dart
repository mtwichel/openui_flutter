import 'package:openui_chat/openui_chat.dart';
import 'package:test/test.dart';

void main() {
  group('Message subclasses', () {
    test('UserMessage auto-generates a UUID id and createdAt', () {
      final m1 = UserMessage(content: 'hi');
      final m2 = UserMessage(content: 'hi');
      expect(m1.id, isNot(m2.id));
      expect(m1.createdAt, isA<DateTime>());
    });

    test('caller can supply id and createdAt', () {
      final ts = DateTime(2026);
      final m = UserMessage(content: 'hi', id: 'fixed', createdAt: ts);
      expect(m.id, 'fixed');
      expect(m.createdAt, ts);
    });

    test('AssistantMessage copyWith preserves identity fields', () {
      final original = AssistantMessage(
        id: 'a',
        createdAt: DateTime(2026),
        response: 'r1',
        isStreaming: true,
      );
      final copy = original.copyWith(response: 'r2', isStreaming: false);
      expect(copy.id, original.id);
      expect(copy.createdAt, original.createdAt);
      expect(copy.response, 'r2');
      expect(copy.isStreaming, isFalse);
    });

    test('equality is structural across subclasses', () {
      final ts = DateTime(2026);
      expect(
        UserMessage(content: 'hi', id: '1', createdAt: ts),
        UserMessage(content: 'hi', id: '1', createdAt: ts),
      );
      expect(
        AssistantMessage(response: 'r', id: '1', createdAt: ts),
        AssistantMessage(response: 'r', id: '1', createdAt: ts),
      );
      expect(
        SystemMessage(content: 's', id: '1', createdAt: ts),
        SystemMessage(content: 's', id: '1', createdAt: ts),
      );
    });

    test('ToolCallMessage compares args deeply', () {
      final ts = DateTime(2026);
      final a = ToolCallMessage(
        id: '1',
        createdAt: ts,
        toolName: 't',
        args: const <String, Object?>{'k': 1},
      );
      final b = ToolCallMessage(
        id: '1',
        createdAt: ts,
        toolName: 't',
        args: const <String, Object?>{'k': 1},
      );
      final c = ToolCallMessage(
        id: '1',
        createdAt: ts,
        toolName: 't',
        args: const <String, Object?>{'k': 2},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('ToolResultMessage equality includes isError', () {
      final ts = DateTime(2026);
      final ok = ToolResultMessage(
        id: '1',
        createdAt: ts,
        toolCallId: 'c1',
        result: 'data',
      );
      final err = ToolResultMessage(
        id: '1',
        createdAt: ts,
        toolCallId: 'c1',
        result: 'data',
        isError: true,
      );
      expect(ok, isNot(equals(err)));
    });
  });
}
