// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('Tool', () {
    test('stores metadata and optional schemas', () {
      final tool = _TestTool(
        name: 'weather',
        description: 'Returns weather data for a city.',
        input: Schema.object(
          properties: {'city': Schema.string()},
          required: ['city'],
        ),
        output: Schema.object(
          properties: {'tempC': Schema.number()},
          required: ['tempC'],
        ),
      );

      expect(tool.name, 'weather');
      expect(tool.description, 'Returns weather data for a city.');
      expect(tool.input, isNotNull);
      expect(tool.output, isNotNull);
      expect(tool.input!.value['type'], 'object');
      expect(tool.output!.value['type'], 'object');
    });

    test('supports tools without input/output schemas', () {
      final tool = _TestTool(
        name: 'ping',
        description: 'Health check.',
      );

      expect(tool.input, isNull);
      expect(tool.output, isNull);
    });

    test(
      'callTool forwards args to implementation and returns ToolResult',
      () async {
        final tool = _TestTool(
          name: 'echo',
          description: 'Echoes arguments.',
          onCall: (args) async => ToolResult({'echo': args}),
        );
        final args = <String, Object?>{'message': 'hi', 'count': 2};

        final result = await tool.callTool(args);

        expect(tool.lastArgs, same(args));
        expect(result.isError, isFalse);
        expect(result.result, {
          'echo': {'message': 'hi', 'count': 2},
        });
      },
    );

    test('callTool may surface tool-level errors', () {
      final tool = _TestTool(
        name: 'missing',
        description: 'Always missing.',
        onCall: (args) => throw const ToolNotFoundError(toolName: 'missing'),
      );

      expect(
        () => tool.callTool(const {}),
        throwsA(isA<ToolNotFoundError>()),
      );
    });
  });

  group('ToolResult', () {
    test('defaults isError to false', () {
      const result = ToolResult('ok');
      expect(result.result, 'ok');
      expect(result.isError, isFalse);
    });

    test('supports null result payload', () {
      const result = ToolResult(null);
      expect(result.result, isNull);
      expect(result.isError, isFalse);
    });

    test('preserves explicit error flag', () {
      const result = ToolResult('permission denied', isError: true);
      expect(result.result, 'permission denied');
      expect(result.isError, isTrue);
    });
  });
}

class _TestTool extends Tool {
  _TestTool({
    required super.name,
    required super.description,
    super.input,
    super.output,
    this.onCall,
  });

  final Future<ToolResult> Function(Map<String, Object?> args)? onCall;
  Map<String, Object?>? lastArgs;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) {
    lastArgs = args;
    if (onCall != null) return onCall!(args);
    return Future.value(const ToolResult({'ok': true}));
  }
}
