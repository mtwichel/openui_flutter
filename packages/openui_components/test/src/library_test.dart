// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';

void main() {
  group('openuiLibrary', () {
    test('registers every v0.1 component', () {
      final lib = openuiLibrary();
      const expected = <String>{
        'Stack',
        'Card',
        'CardHeader',
        'Separator',
        'Callout',
        'TextContent',
        'MarkDownRenderer',
        'Image',
        'CodeBlock',
        'Form',
        'FormControl',
        'Input',
        'Select',
        'Button',
        'Buttons',
        'Table',
        'Col',
        'Tabs',
        'TabItem',
        'BarChart',
        'LineChart',
      };
      expect(lib.names.toSet(), expected);
    });

    test('each registration carries a non-empty schema', () {
      final lib = openuiLibrary();
      for (final name in lib.names) {
        final component = lib[name]!;
        expect(component.schema, isNotNull);
        expect(component.schema.value['type'], 'object');
      }
    });

    test('openuiChatLibrary returns the same component set', () {
      expect(
        openuiChatLibrary().names.toSet(),
        openuiLibrary().names.toSet(),
      );
    });

    test('prompt excludes Col and TabItem, includes all other components', () {
      final result = openuiLibrary().prompt(const PromptOptions());
      // Internal components must not appear.
      expect(result, isNot(contains('Col(')));
      expect(result, isNot(contains('TabItem(')));
      // All non-internal components must be present.
      const expected = <String>[
        'Stack',
        'Card',
        'CardHeader',
        'Separator',
        'Callout',
        'TextContent',
        'MarkDownRenderer',
        'Image',
        'CodeBlock',
        'Form',
        'FormControl',
        'Input',
        'Select',
        'Button',
        'Buttons',
        'Table',
        'Tabs',
        'BarChart',
        'LineChart',
      ];
      for (final name in expected) {
        expect(result, contains('$name('), reason: '$name missing from prompt');
      }
    });
  });

  group('component render type', () {
    test('renders return Widget', () {
      final lib = openuiLibrary();
      final ctx = EvalContext(
        statements: const <Statement>[],
        store: Store(),
        builtins: functionalBuiltins,
      );
      addTearDown(ctx.store.dispose);

      Widget stubRender(AstNode _, EvalContext _) => const SizedBox.shrink();

      // Smoke test: call render with empty props and a stub renderNode.
      for (final name in lib.names) {
        final component = lib[name]!;
        final widget = component.render(
          ctx,
          const <String, Object?>{},
          stubRender,
          name,
        );
        expect(widget, isA<Widget>(), reason: 'component $name');
      }
    });
  });
}
