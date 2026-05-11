import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter_example/main.dart';

void main() {
  testWidgets('boots into AppShell with the scripts demo selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const OpenUIExampleApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    // Existing scripted demo's chips are visible by default.
    expect(find.text('1. Hello'), findsOneWidget);
    expect(find.text('5. Charts'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
  });
}
