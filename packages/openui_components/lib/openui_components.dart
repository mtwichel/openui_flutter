/// Builtin component library for OpenUI Flutter.
///
/// This is the only file consumers should import from
/// `openui_components`. The `src/` tree is private. Every public
/// symbol is currently marked `@experimental` — the shape may change
/// between v0.1 and v0.2.
library;

export 'src/components/bar_chart.dart' show BarChartWidget;
export 'src/components/button.dart' show ButtonWidget;
export 'src/components/callout.dart' show CalloutWidget;
export 'src/components/card.dart' show CardHeaderWidget, CardWidget;
export 'src/components/image.dart' show ImageWidget;
export 'src/components/input.dart' show InputWidget;
export 'src/components/line_chart.dart' show LineChartWidget;
export 'src/components/markdown.dart' show MarkDownRendererWidget;
export 'src/components/select.dart' show SelectWidget;
export 'src/components/stack.dart' show StackWidget;
export 'src/components/table.dart' show TableWidget;
export 'src/components/tabs.dart' show TabItemDescription, TabsWidget;
export 'src/components/text_content.dart' show TextContentWidget;
export 'src/internal/tokens.dart'
    show kSpacingTokens, kTextSizeTokens, resolveSpacing;
export 'src/openui_library.dart'
    show standardComponentRegistry, standardLibraryDefinition;
