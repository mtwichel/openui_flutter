// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

RendererScope _scope({
  required Widget child,
  Store? store,
  FormStateCache? cache,
  bool isStreaming = false,
  Set<String> incomplete = const <String>{},
  Future<void> Function(
    String userMessage, {
    ActionPlan? action,
  })?
  triggerAction,
}) {
  return RendererScope(
    store: store ?? Store(),
    formStateCache: cache ?? FormStateCache(),
    isStreaming: isStreaming,
    incomplete: incomplete,
    triggerAction: triggerAction ?? (_, {action}) async {},
    child: child,
  );
}

void main() {
  group('RendererScope', () {
    testWidgets('of returns the nearest scope', (tester) async {
      RendererScope? captured;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _scope(
            child: Builder(
              builder: (context) {
                captured = RendererScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(captured, isNotNull);
    });

    testWidgets('maybeFind returns null when no scope is mounted', (
      tester,
    ) async {
      RendererScope? captured;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              captured = RendererScope.maybeFind(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isNull);
    });

    testWidgets(
      'triggerAction without an action plan runs without error',
      (tester) async {
        var fired = false;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _scope(
              triggerAction: (msg, {action}) async {
                fired = true;
              },
              child: Builder(
                builder: (context) {
                  unawaited(
                    RendererScope.of(context).triggerAction('hi'),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(fired, isTrue);
      },
    );

    testWidgets(
      "triggerAction('') still calls through — empty-message filtering "
      "is the host controller's job",
      (tester) async {
        String? seen;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _scope(
              triggerAction: (msg, {action}) async {
                seen = msg;
              },
              child: Builder(
                builder: (context) {
                  unawaited(
                    RendererScope.of(context).triggerAction(''),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(seen, '');
      },
    );

    testWidgets('updateShouldNotify fires on isStreaming change', (
      tester,
    ) async {
      var builds = 0;
      Widget consumer(_) {
        builds++;
        return const SizedBox.shrink();
      }

      final store = Store();
      addTearDown(store.dispose);
      final cache = FormStateCache();
      addTearDown(cache.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _scope(
            store: store,
            cache: cache,
            child: Builder(
              builder: (context) {
                RendererScope.of(context);
                return consumer(context);
              },
            ),
          ),
        ),
      );
      expect(builds, 1);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _scope(
            store: store,
            cache: cache,
            isStreaming: true,
            child: Builder(
              builder: (context) {
                RendererScope.of(context);
                return consumer(context);
              },
            ),
          ),
        ),
      );
      expect(builds, 2);
    });

    test('updateShouldNotify returns false when nothing changes', () {
      final store = Store();
      addTearDown(store.dispose);
      final cache = FormStateCache();
      addTearDown(cache.dispose);

      RendererScope build({
        bool isStreaming = false,
        Set<String> incomplete = const <String>{},
      }) {
        return RendererScope(
          store: store,
          formStateCache: cache,
          isStreaming: isStreaming,
          incomplete: incomplete,
          triggerAction: (_, {action}) async {},
          child: const SizedBox.shrink(),
        );
      }

      expect(build().updateShouldNotify(build()), isFalse);
      expect(
        build(isStreaming: true).updateShouldNotify(build()),
        isTrue,
      );
      expect(
        build(incomplete: {'a'}).updateShouldNotify(build()),
        isTrue,
      );
    });
  });
}
