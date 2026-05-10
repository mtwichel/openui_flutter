// Phase 0 placeholder. Real helpers land alongside the consumer packages
// they support; tests come with them.

// The barrel is intentionally empty in Phase 0; importing it here is the
// only way to assert the public surface compiles.
// ignore: unused_import
import 'package:openui_test_helpers/openui_test_helpers.dart';
import 'package:test/test.dart';

void main() {
  test('Phase 0 scaffold compiles', () {
    expect(1 + 1, 2);
  });
}
