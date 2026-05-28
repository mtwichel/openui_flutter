// Canonical comparison §2.3 — simplified dashboard query fixture.
// Full chart idiom (`data.rows.field`) still needs array pluck (partial parity).
// ignore_for_file: experimental_member_use, lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

import '../helpers/wiring.dart';

class _FixtureRoot extends StatelessWidget {
  const _FixtureRoot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: Material(child: child));
}

/// §2.3 shape: `$days` state drives `Query("analytics", {days: $days}, …)`.
const _canonicalSection23 = r'''
$days = "7"
root = Column([title, chart])
title = Text("Showing last " + $days + " days")
data = Query("analytics", {days: $days}, {label: "Loading"})
chart = Text(data.label)
''';

void main() {
  group('canonical §2.3 query fixture', () {
    testWidgets(
      'parses, shows defaults while loading, re-fetches on days change',
      (tester) async {
        final dayArgs = <Object?>[];
        final secondFetch = Completer<ToolResult>();
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'analytics',
              description: 'analytics',
              execute: (args) async {
                dayArgs.add(args['days']);
                if (dayArgs.length == 1) {
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  return ToolResult(
                    <String, Object?>{'label': '${args['days']}-day views'},
                  );
                }
                return secondFetch.future;
              },
            ),
          ],
        );

        await tester.pumpWidget(
          _FixtureRoot(
            child: Renderer(
              response: _canonicalSection23,
              library: harness.library,
              componentRegistry: harness.componentRegistry,
              toolRegistry: harness.toolRegistry,
            ),
          ),
        );
        await tester.pump();
        expect(dayArgs, ['7']);
        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('Showing last 7 days'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();
        expect(find.text('7-day views'), findsOneWidget);

        RendererScope.of(tester.element(find.byType(RendererScope))).store.set(
          r'$days',
          '30',
        );
        await tester.pump();
        expect(dayArgs, ['7', '30']);
        expect(find.text('7-day views'), findsOneWidget);
        expect(find.text('Loading'), findsNothing);
        expect(find.text('Showing last 30 days'), findsOneWidget);

        secondFetch.complete(
          const ToolResult(<String, Object?>{'label': '30-day views'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('30-day views'), findsOneWidget);
      },
    );
  });
}
