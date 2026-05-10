import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter_example/main.dart';

void main() {
  testWidgets('placeholder home renders Phase 0 message', (tester) async {
    await tester.pumpWidget(const OpenUIExampleApp());
    expect(find.textContaining('Phase 0 scaffold'), findsOneWidget);
  });
}
