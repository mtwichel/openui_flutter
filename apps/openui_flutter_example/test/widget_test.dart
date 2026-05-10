import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter_example/main.dart';

void main() {
  testWidgets('boots with the hello script picker visible', (tester) async {
    await tester.pumpWidget(const OpenUIExampleApp());
    // First frame: no messages yet.
    expect(find.text('1. Hello'), findsOneWidget);
    expect(find.text('2. Counter'), findsOneWidget);
    expect(find.text('5. Charts'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
  });
}
