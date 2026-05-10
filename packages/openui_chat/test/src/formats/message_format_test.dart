import 'package:openui_chat/openui_chat.dart';
import 'package:test/test.dart';

void main() {
  final ts = DateTime(2026);

  group('identityFormat', () {
    test('serializes every message kind with id + role + content', () {
      final out = identityFormat(<Message>[
        UserMessage(id: 'u', createdAt: ts, content: 'hi'),
        AssistantMessage(id: 'a', createdAt: ts, response: 'hello'),
        SystemMessage(id: 's', createdAt: ts, content: 'be helpful'),
        ToolCallMessage(
          id: 'tc',
          createdAt: ts,
          toolName: 't',
          args: const <String, Object?>{'k': 1},
        ),
        ToolResultMessage(
          id: 'tr',
          createdAt: ts,
          toolCallId: 'tc',
          result: 'data',
        ),
      ]);

      expect(out.length, 5);
      expect(out[0], <String, Object?>{
        'id': 'u',
        'role': 'user',
        'content': 'hi',
      });
      expect(out[1], <String, Object?>{
        'id': 'a',
        'role': 'assistant',
        'content': 'hello',
      });
      expect(out[2]['role'], 'system');
      expect(out[3]['role'], 'tool_call');
      expect(out[4]['role'], 'tool_result');
    });
  });

  group('openAiFormat', () {
    test('drops tool messages and emits {role, content} entries', () {
      final out = openAiFormat(<Message>[
        UserMessage(id: 'u', createdAt: ts, content: 'hi'),
        AssistantMessage(id: 'a', createdAt: ts, response: 'hello'),
        ToolCallMessage(
          id: 'tc',
          createdAt: ts,
          toolName: 't',
          args: const <String, Object?>{},
        ),
        SystemMessage(id: 's', createdAt: ts, content: 'be helpful'),
      ]);

      expect(out, <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'hi'},
        <String, Object?>{'role': 'assistant', 'content': 'hello'},
        <String, Object?>{'role': 'system', 'content': 'be helpful'},
      ]);
    });
  });

  group('openAiResponsesFormat', () {
    test('wraps content in {type:"text", text} blocks', () {
      final out = openAiResponsesFormat(<Message>[
        UserMessage(id: 'u', createdAt: ts, content: 'hi'),
      ]);
      expect(out, <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': <Map<String, Object?>>[
            <String, Object?>{'type': 'text', 'text': 'hi'},
          ],
        },
      ]);
    });

    test('drops tool messages, emits assistant + system', () {
      final out = openAiResponsesFormat(<Message>[
        AssistantMessage(id: 'a', createdAt: ts, response: 'r'),
        ToolResultMessage(
          id: 'tr',
          createdAt: ts,
          toolCallId: 'c',
          result: 'x',
        ),
        SystemMessage(id: 's', createdAt: ts, content: 's'),
      ]);
      expect(out.length, 2);
      expect(out[0]['role'], 'assistant');
      expect(out[1]['role'], 'system');
    });
  });
}
