/// Token table for spacing values consumed by `gap`, `padding`, and
/// similar layout props. The size keys (`xs`/`s`/`m`/`l`/`xl`) are the
/// JS reference's vocabulary; the values are pulled from Material's
/// 4 / 8 / 16 / 24 / 32 dp grid so the result composes with the
/// surrounding theme.
const Map<String, double> kSpacingTokens = <String, double>{
  'xs': 4,
  's': 8,
  'm': 16,
  'l': 24,
  'xl': 32,
};

/// Resolves a `gap` or `padding` token to a `double`. Accepts:
/// - a [String] in [kSpacingTokens]
/// - a [num] (pass-through)
/// - `null` (returns [fallback])
double resolveSpacing(Object? token, {double fallback = 0}) {
  if (token is num) return token.toDouble();
  if (token is String) return kSpacingTokens[token] ?? fallback;
  return fallback;
}

/// Token table for `TextContent` semantic size variants. The keys
/// mirror the JS reference's `large-heavy` / `medium` / `small-light`
/// vocabulary; the values are constructed from Material's text theme
/// at build time, so the widget reads them through a `BuildContext`.
const Set<String> kTextSizeTokens = <String>{
  'display-heavy',
  'large-heavy',
  'large',
  'medium-heavy',
  'medium',
  'small-heavy',
  'small',
  'small-light',
};
