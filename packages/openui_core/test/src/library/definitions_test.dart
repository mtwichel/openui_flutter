import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('LibraryDefinition serialization', () {
    test('round-trips components and tools with nested schemas', () {
      final library = LibraryDefinition(
        components: [
          ComponentDefinition(
            name: 'Button',
            description: 'tappable button with action',
            schema: Schema.object(
              properties: {
                'label': Schema.string(),
                'variant': Schema.string(
                  enumValues: ['primary', 'secondary', 'text'],
                ),
                'onClick': Schema.any(),
              },
              required: ['label'],
            ),
          ),
          ComponentDefinition(
            name: 'Col',
            internal: true,
            schema: Schema.object(
              properties: {'width': Schema.number()},
            ),
          ),
        ],
        tools: [
          ToolDefinition(
            name: 'fetch_products',
            description: 'fetch catalog products',
            input: Schema.object(
              properties: {
                'limit': Schema.integer(),
                'skip': Schema.integer(),
              },
            ),
            output: Schema.object(
              properties: {
                'products': Schema.list(items: Schema.object(properties: {})),
                'total': Schema.integer(),
              },
            ),
          ),
        ],
        libraryPrompt: 'Use these components sparingly.',
      );

      final decoded = LibraryDefinition.fromJson(library.toJson());

      expect(decoded.libraryPrompt, library.libraryPrompt);
      expect(decoded.components.length, 2);
      expect(decoded.components.first.name, 'Button');
      expect(
        decoded.components.first.schema.value['properties'],
        isA<Map<String, Object?>>(),
      );
      expect(decoded.components.last.internal, isTrue);
      expect(decoded.tools.single.name, 'fetch_products');
      expect(
        decoded.tool('fetch_products')!.description,
        'fetch catalog products',
      );
      expect(
        decoded.component('Button')!.description,
        'tappable button with action',
      );
    });
  });
}
