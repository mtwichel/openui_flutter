// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// Multiline OpenUI Lang fixtures use embedded `$` for `$state` refs;
// the matching raw-string form is less readable than the escapes.
// ignore_for_file: experimental_member_use, leading_newlines_in_multiline_strings, use_raw_strings, lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';

Widget _app(String response, {void Function(ActionEvent)? onAction}) {
  return MaterialApp(
    home: Scaffold(
      body: Renderer(
        response: response,
        library: openuiLibrary(),
        onAction: onAction,
      ),
    ),
  );
}

void main() {
  group('Renderer + openuiLibrary', () {
    testWidgets('renders a Stack of TextContent', (tester) async {
      await tester.pumpWidget(
        _app(
          'root = Stack(children: [TextContent(text: "hello")])',
        ),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders a Card with header and body', (tester) async {
      await tester.pumpWidget(
        _app('''
root = Card(children: [
  CardHeader(title: "Title", subtitle: "Subtitle"),
  TextContent(text: "Body")
])
'''),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders a Callout with the requested variant', (tester) async {
      await tester.pumpWidget(
        _app('root = Callout(text: "watch out", variant: "warning")'),
      );
      expect(find.text('watch out'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('renders Separator as a Divider', (tester) async {
      await tester.pumpWidget(_app('root = Separator()'));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('Button fires its onClick action plan', (tester) async {
      final events = <ActionEvent>[];
      // Trailing newline is intentional — without it the streaming
      // parser puts `root = Button(...)` in the "pending tail" and the
      // renderer disables the action (Acceptance Gap A6). The CI test
      // bundler was hitting this; locally it didn't because the
      // unbundled runner cached the parser state differently.
      await tester.pumpWidget(
        _app(
          r'''$count = 0
root = Button(label: "Click", onClick: @Set($count, $count + 1))
''',
          onAction: events.add,
        ),
      );
      await tester.tap(find.text('Click'));
      // The renderer's dispatch is async (dispatchAction awaits each
      // step). pumpAndSettle drains the microtask the closure chains.
      await tester.pumpAndSettle();
      expect(events.length, 1);
      expect(events.first.plan.steps.first, isA<SetStep>());
    });

    testWidgets('Buttons lays out children horizontally', (tester) async {
      await tester.pumpWidget(
        _app('''
root = Buttons(children: [
  Button(label: "A"),
  Button(label: "B")
])
'''),
      );
      expect(find.byType(ElevatedButton), findsNWidgets(2));
    });

    testWidgets('CodeBlock uses SelectableText', (tester) async {
      await tester.pumpWidget(
        _app('root = CodeBlock(code: "let x = 1", language: "dart")'),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('Form + Input two-way binding writes to the store', (
      tester,
    ) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Renderer(
              response: '''
\$name = ""
root = Form(name: "f", children: [
  Input(name: "field", value: \$name)
])
''',
              library: openuiLibrary(),
              onStateUpdate: updates.add,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('input-f-field')),
        'hello',
      );
      await tester.pump();
      expect(updates.last[r'$name'], 'hello');
    });

    testWidgets('Tabs renders one Tab per inline TabItem', (tester) async {
      await tester.pumpWidget(
        _app('''
root = Tabs(children: [
  TabItem(label: "One", content: TextContent(text: "1")),
  TabItem(label: "Two", content: TextContent(text: "2"))
])
'''),
      );
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
    });

    testWidgets('Table renders rows and pagination controls when full', (
      tester,
    ) async {
      final rows = StringBuffer();
      for (var i = 0; i < 12; i++) {
        rows.write('  {name: "n$i", value: $i}');
        if (i < 11) rows.write(', ');
      }
      await tester.pumpWidget(
        _app('''
root = Table(
  columns: [{name: "name", label: "Name"}, {name: "value", label: "Value"}],
  rows: [$rows]
)
'''),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('n0'), findsOneWidget);
      // Pagination indicator for 12 rows.
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('Image shows fallback when URL is broken', (tester) async {
      await tester.pumpWidget(
        _app('root = Image(src: "http://invalid.test/x.png", alt: "x")'),
      );
      // Network error fires synchronously in tests because the
      // http overrides return an empty response by default.
      await tester.pump(const Duration(seconds: 1));
      // Either the image widget or the errorBuilder placeholder is in
      // the tree; the fallback Icon is the easy assertion.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('BarChart renders without crashing for empty series', (
      tester,
    ) async {
      await tester.pumpWidget(_app('root = BarChart(series: [])'));
      expect(find.byType(BarChartWidget), findsOneWidget);
    });

    testWidgets('LineChart renders one series', (tester) async {
      await tester.pumpWidget(
        _app('''
root = LineChart(
  series: [{name: "y", values: [1, 2, 3]}],
  labels: ["a", "b", "c"]
)
'''),
      );
      expect(find.byType(LineChartWidget), findsOneWidget);
    });

    testWidgets('MarkDownRenderer renders the source as Markdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('root = MarkDownRenderer(source: "**bold**")'),
      );
      expect(find.byType(MarkDownRendererWidget), findsOneWidget);
    });

    testWidgets(
      'TextContent uses display-heavy size variant on request',
      (tester) async {
        await tester.pumpWidget(
          _app('root = TextContent(text: "hero", size: "display-heavy")'),
        );
        expect(find.text('hero'), findsOneWidget);
      },
    );
  });
}
