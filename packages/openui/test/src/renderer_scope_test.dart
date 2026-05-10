// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

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
}) {
  return RendererScope(
    store: store ?? Store(),
    formStateCache: cache ?? FormStateCache(),
    isStreaming: isStreaming,
    incomplete: incomplete,
    onActionAst: (_, _, {payload}) async {},
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

    testWidgets('updateShouldNotify does not fire when nothing changes', (
      tester,
    ) async {
      var builds = 0;
      final store = Store();
      addTearDown(store.dispose);
      final cache = FormStateCache();
      addTearDown(cache.dispose);

      Widget tree() => Directionality(
        textDirection: TextDirection.ltr,
        child: _scope(
          store: store,
          cache: cache,
          child: Builder(
            builder: (context) {
              RendererScope.of(context);
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(tree());
      await tester.pumpWidget(tree());
      expect(builds, 1);
    });
  });
}
