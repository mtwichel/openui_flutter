// Phase 0 placeholder. Substantive widget tests for `Renderer` land in
// Phase 2 alongside the implementation.

import 'package:flutter_test/flutter_test.dart';
// The barrel is intentionally empty in Phase 0; importing it here is the
// only way to assert the public surface compiles.
// ignore: unused_import
import 'package:openui/openui.dart';

void main() {
  test('Phase 0 scaffold compiles', () {
    // The non-trivial assertion is the import above: if the barrel breaks,
    // this file fails to compile. The runtime body has nothing to check
    // until the Renderer lands.
    expect(1 + 1, 2);
  });
}
