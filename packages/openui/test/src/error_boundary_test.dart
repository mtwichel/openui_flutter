// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('renders the child when build succeeds', (tester) async {
      final errors = <OpenUIError>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ErrorBoundary(
            statementId: 'root',
            onError: errors.add,
            builder: (_) => const Text('ok'),
          ),
        ),
      );

      expect(find.text('ok'), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets(
      'shows the cached child and reports when the build throws',
      (tester) async {
        var shouldThrow = false;
        final reported = <OpenUIError>[];
        final notifier = ValueNotifier<int>(0);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (_, value, _) => ErrorBoundary(
                statementId: 'root',
                onError: reported.add,
                builder: (_) {
                  if (shouldThrow) throw StateError('boom');
                  return Text('value-$value');
                },
              ),
            ),
          ),
        );
        expect(find.text('value-0'), findsOneWidget);
        expect(reported, isEmpty);

        // Trigger a re-build that throws.
        shouldThrow = true;
        notifier.value = 1;
        await tester.pump();

        // Last-good child still rendered, error reported.
        expect(find.text('value-0'), findsOneWidget);
        expect(reported.length, 1);
        expect(reported.first, isA<OpenUIError>());

        // Flutter framework caught the synchronous throw — drain it.
        tester.takeException();

        // Next non-throwing build replaces the cached child.
        shouldThrow = false;
        notifier.value = 2;
        await tester.pump();
        expect(find.text('value-2'), findsOneWidget);
        expect(reported.length, 1, reason: 'no new error on recovery');
      },
    );

    testWidgets(
      'returns an empty placeholder when the first build throws',
      (tester) async {
        final reported = <OpenUIError>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ErrorBoundary(
              statementId: 'root',
              onError: reported.add,
              builder: (_) => throw StateError('first build fails'),
            ),
          ),
        );

        // Captured cleanly — no widget surface, but reported.
        expect(reported.length, 1);
        tester.takeException();
      },
    );

    testWidgets('passes OpenUIError through verbatim', (tester) async {
      final reported = <OpenUIError>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ErrorBoundary(
            statementId: 'root',
            onError: reported.add,
            builder: (_) => throw const ParseError(
              message: 'bad',
              offset: 0,
            ),
          ),
        ),
      );

      expect(reported.length, 1);
      expect(reported.first, isA<ParseError>());
      tester.takeException();
    });
  });
}
