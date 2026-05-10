// Phase 0 placeholder. The McpToolProvider and extractToolResult tests land
// in Phase 4.

// The barrel is intentionally empty in Phase 0; importing it here is the
// only way to assert the public surface compiles.
// ignore: unused_import
import 'package:openui_mcp/openui_mcp.dart';
import 'package:test/test.dart';

void main() {
  test('Phase 0 scaffold compiles', () {
    expect(1 + 1, 2);
  });
}
