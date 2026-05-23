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
      final lib = standardLibraryDefinition();
      const expected = <String>{
        'Stack',
        'Card',
        'CardHeader',
        'Separator',
        'Callout',
        'TextContent',
        'MarkDownRenderer',
        'Image',
        'Input',
        'Select',
        'Button',
        'Table',
        'Col',
        'Tabs',
        'TabItem',
        'BarChart',
        'LineChart',
      };
      expect(lib.components.map((c) => c.name).toSet(), expected);
    });

    test('each registration carries a non-empty schema', () {
      final lib = standardLibraryDefinition();
      for (final name in lib.components.map((c) => c.name)) {
        final component = lib.component(name)!;
        expect(component.schema, isNotNull);
        expect(component.schema.value['type'], 'object');
      }
    });

    test('prompt excludes Col and TabItem, includes all other components', () {
      final result = standardLibraryDefinition().prompt();
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
        'Input',
        'Select',
        'Button',
        'Table',
        'Tabs',
        'BarChart',
        'LineChart',
      ];
      for (final name in expected) {
        expect(
          result,
          contains('$name('),
          reason: '$name missing from prompt',
        );
      }
    });

    test('standardComponentRegistry registers every definition', () {
      final lib = standardLibraryDefinition();
      final registry = standardComponentRegistry();
      for (final component in lib.components) {
        expect(
          registry[component.name],
          isNotNull,
          reason: 'missing renderer for ${component.name}',
        );
      }
    });
  });

  group('component render type', () {
    test('renders return Widget', () {
      final lib = standardLibraryDefinition();
      final registry = standardComponentRegistry();
      final ctx = EvalContext(
        statements: const <Statement>[],
        store: Store(),
        builtins: functionalBuiltins,
      );
      addTearDown(ctx.store.dispose);

      Widget stubRender(AstNode _, EvalContext _) => const SizedBox.shrink();

      // Smoke test: call render with empty props and a stub renderNode.
      for (final component in lib.components) {
        final render = registry[component.name]!;
        final widget = render(
          ctx,
          const <String, Object?>{},
          stubRender,
          component.name,
        );
        expect(widget, isA<Widget>(), reason: 'component ${component.name}');
      }
    });
  });
}
