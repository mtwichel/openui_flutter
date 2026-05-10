import 'package:flutter_test/flutter_test.dart';
import 'package:openui_components/openui_components.dart';

void main() {
  group('resolveSpacing', () {
    test('resolves the spacing tokens', () {
      expect(resolveSpacing('xs'), 4);
      expect(resolveSpacing('s'), 8);
      expect(resolveSpacing('m'), 16);
      expect(resolveSpacing('l'), 24);
      expect(resolveSpacing('xl'), 32);
    });

    test('passes through num values', () {
      expect(resolveSpacing(12), 12);
      expect(resolveSpacing(12.5), 12.5);
    });

    test('falls back when the token is unknown', () {
      expect(resolveSpacing('mega'), 0);
      expect(resolveSpacing(null, fallback: 4), 4);
    });
  });

  test('kSpacingTokens and kTextSizeTokens are non-empty constants', () {
    expect(kSpacingTokens, isNotEmpty);
    expect(kTextSizeTokens, isNotEmpty);
  });
}
