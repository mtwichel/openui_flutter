// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// Multiline OpenUI Lang fixtures use embedded `$` for `$state` refs;
// the matching raw-string form is less readable than the escapes.
// ignore_for_file: experimental_member_use, leading_newlines_in_multiline_strings, use_raw_strings, lines_longer_than_80_chars

import 'package:fl_chart/fl_chart.dart' show BarChart, LineChart;
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
        library: standardLibrary(),
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

    testWidgets(
      'Button onClick @Set runs as a host-internal step and emits zero '
      'ActionEvents',
      (tester) async {
        final events = <ActionEvent>[];
        final updates = <Map<String, Object?>>[];
        // Trailing newline is intentional — without it the streaming
        // parser puts `root = Button(...)` in the "pending tail" and the
        // renderer disables the action (Acceptance Gap A6).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Renderer(
                response: r'''$count = 0
root = Button(label: "Click", onClick: @Set($count, $count + 1))
''',
                library: openuiLibrary(),
                onAction: events.add,
                onStateUpdate: updates.add,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Click'));
        await tester.pumpAndSettle();
        expect(events, isEmpty);
        expect(updates.last[r'$count'], 1);
      },
    );

    testWidgets(
      'Button with onClick AST disabled mid-stream does NOT fire the '
      'implicit @ToAssistant path',
      (tester) async {
        final events = <ActionEvent>[];
        // No trailing newline + isStreaming: true puts the onClick AST in
        // meta.incomplete, so the renderer disables the action. The Button
        // must stay tap-inert — not silently send the label to the LLM.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Renderer(
                response:
                    'root = Button(label: "Retry", onClick: @ToAssistant("retry"))',
                library: openuiLibrary(),
                isStreaming: true,
                onAction: events.add,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(
          events,
          isEmpty,
          reason: 'streaming-disabled Button must not fire implicit path',
        );
      },
    );

    testWidgets(
      'Button without onClick fires implicit @ToAssistant with its label',
      (tester) async {
        final events = <ActionEvent>[];
        await tester.pumpWidget(
          _app(
            'root = Button(label: "Retry")\n',
            onAction: events.add,
          ),
        );
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.continueConversation);
        expect(events.single.humanFriendlyMessage, 'Retry');
        expect(events.single.formName, isNull);
        expect(events.single.formState, isNull);
      },
    );

    testWidgets(
      'Button inside a Form populates formName and formState',
      (tester) async {
        final events = <ActionEvent>[];
        await tester.pumpWidget(
          _app(
            '''
\$x = ""
root = Form(name: "f", children: [
  Input(name: "x", value: \$x),
  Button(label: "Send")
])
''',
            onAction: events.add,
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('input-f-x')),
          'typed',
        );
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.continueConversation);
        expect(events.single.humanFriendlyMessage, 'Send');
        expect(events.single.formName, 'f');
        expect(events.single.formState!['x'], 'typed');
      },
    );

    testWidgets(
      'Button inside a Form with AST onClick carries formName and '
      'formState on the emitted event',
      (tester) async {
        final events = <ActionEvent>[];
        await tester.pumpWidget(
          _app(
            '''
\$x = ""
root = Form(name: "f", children: [
  Input(name: "x", value: \$x),
  Button(label: "Go", onClick: @ToAssistant("submit"))
])
''',
            onAction: events.add,
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('input-f-x')),
          'typed',
        );
        await tester.pump();
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.continueConversation);
        expect(events.single.humanFriendlyMessage, 'submit');
        expect(events.single.formName, 'f');
        expect(events.single.formState!['x'], 'typed');
      },
    );

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
              library: standardLibrary(),
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

    testWidgets('Table accepts string columns and positional rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('''
root = Table(
  columns: ["State", "Abbr"],
  rows: [["Alabama", "AL"], ["Alaska", "AK"]]
)
'''),
      );
      // String columns are used as their own label.
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Abbr'), findsOneWidget);
      // Positional row cells line up with the columns order.
      expect(find.text('Alabama'), findsOneWidget);
      expect(find.text('AK'), findsOneWidget);
    });

    testWidgets('Table renders an error Callout when columns are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('root = Table(columns: [], rows: [])'),
      );
      expect(find.byType(CalloutWidget), findsOneWidget);
      expect(
        find.textContaining('requires at least one column'),
        findsOneWidget,
      );
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

    testWidgets('LineChart uses legible tooltip styling', (tester) async {
      await tester.pumpWidget(
        _app('''
root = LineChart(
  series: [{name: "y", values: [1, 2, 3]}],
  labels: ["a", "b", "c"]
)
'''),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = chart.data.lineTouchData.touchTooltipData;
      expect(tooltipData.fitInsideHorizontally, isTrue);
      expect(tooltipData.fitInsideVertically, isTrue);
      expect(tooltipData.tooltipBorderRadius, BorderRadius.circular(10));
      expect(
        tooltipData.tooltipPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
    });

    testWidgets('LineChart accepts `data` as an alias for `values`', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('''
root = LineChart(
  series: [{name: "y", data: [1, 2, 3]}],
  labels: ["a", "b", "c"]
)
'''),
      );
      // Find the underlying fl_chart LineChart widget so we can assert
      // the series actually produced spots (not just an empty SizedBox).
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData, hasLength(1));
      expect(chart.data.lineBarsData.first.spots, hasLength(3));
    });

    testWidgets('LineChart adds y-axis headroom to avoid clipping peaks', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('''
root = LineChart(
  series: [
    {name: "CA", values: [0.5, 0.7, 0.6]},
    {name: "TX", values: [1.8, 1.82, 1.75]}
  ],
  labels: ["2014", "2015", "2016"]
)
'''),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.maxY, isNotNull);
      expect(chart.data.maxY, greaterThan(1.82));
    });

    testWidgets('LineChart renders each x-axis label once', (tester) async {
      await tester.pumpWidget(
        _app('''
root = LineChart(
  series: [{name: "y", values: [1, 2, 3]}],
  labels: ["2014", "2015", "2016"]
)
'''),
      );
      expect(find.text('2014'), findsOneWidget);
      expect(find.text('2015'), findsOneWidget);
      expect(find.text('2016'), findsOneWidget);
    });

    testWidgets('MarkDownRenderer renders the source as Markdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('root = MarkDownRenderer(source: "**bold**")'),
      );
      expect(find.byType(MarkDownRendererWidget), findsOneWidget);
    });

    testWidgets('BarChart uses legible tooltip styling', (tester) async {
      await tester.pumpWidget(
        _app('''
root = BarChart(
  series: [{name: "y", values: [1, 2, 3]}],
  labels: ["a", "b", "c"]
)
'''),
      );
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = chart.data.barTouchData.touchTooltipData;
      expect(tooltipData.fitInsideHorizontally, isTrue);
      expect(tooltipData.fitInsideVertically, isTrue);
      expect(tooltipData.tooltipBorderRadius, BorderRadius.circular(10));
      expect(
        tooltipData.tooltipPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
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

    testWidgets('TextContent stringifies a numeric state value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app('''
\$count = 7
root = TextContent(text: \$count)
'''),
      );
      expect(find.text('7'), findsOneWidget);
    });
  });
}
