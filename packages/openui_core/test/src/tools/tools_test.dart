// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('Tool', () {
    test('stores metadata and optional schemas', () {
      final tool = Tool(
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
      const tool = Tool(
        name: 'ping',
        description: 'Health check.',
      );

      expect(tool.input, isNull);
      expect(tool.output, isNull);
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
