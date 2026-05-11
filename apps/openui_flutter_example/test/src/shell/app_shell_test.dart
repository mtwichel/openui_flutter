import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openui_flutter_example/src/shell/app_shell.dart';

Widget _harness() => const MaterialApp(home: AppShell());

void main() {
  group('AppShell', () {
    testWidgets('wide viewport: NavigationRail visible, Scripts is default', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_harness());

      expect(find.byType(NavigationRail), findsOneWidget);
      // Scripts demo chips are visible by default.
      expect(find.text('1. Hello'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(5));
    });

    testWidgets('narrow viewport: Drawer-based nav, no NavigationRail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_harness());

      expect(find.byType(NavigationRail), findsNothing);
      // The Scripts screen exposes a hamburger leading in narrow mode.
      expect(find.byTooltip('Open menu'), findsOneWidget);
    });

    testWidgets('wide viewport: NavigationRail offers both destinations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_harness());

      // Both destinations show in the rail. Tapping `Live` triggers real
      // `DartanticChatService` construction (which requires a registered
      // dartantic provider factory), so the navigation result itself is
      // covered by `llm_chat_screen_test.dart` rather than here.
      expect(find.text('Scripts'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });
  });
}
