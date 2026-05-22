// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:openui_core/openui_core.dart';

/// `BarChart(series, labels?)` — multi-series bar chart. `series` is a
/// list of `{name: String, values: List<num>}` maps. `labels` is the
/// x-axis label list; defaults to the index when omitted.
class BarChartWidget extends StatelessWidget {
  /// Creates a [BarChartWidget].
  const BarChartWidget({
    required this.series,
    this.labels,
    this.height = 220,
    super.key,
  });

  /// Series definitions.
  final List<({String name, List<num> values})> series;

  /// X-axis labels (optional).
  final List<String>? labels;

  /// Layout height.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return SizedBox(height: height);
    final groupCount = series.map((s) => s.values.length).reduce(_max);
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final seriesName = series[rodIndex].name;
                final label = labels != null && group.x < labels!.length
                    ? labels![group.x]
                    : '${group.x}';
                final value = _formatTooltipValue(rod.toY);
                return BarTooltipItem(
                  '$seriesName\n$label: $value',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                );
              },
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < groupCount; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: <BarChartRodData>[
                  for (var s = 0; s < series.length; s++)
                    BarChartRodData(
                      toY: i < series[s].values.length
                          ? series[s].values[i].toDouble()
                          : 0,
                      color: palette[s % palette.length],
                      width: 12,
                    ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  final label = labels != null && i < labels!.length
                      ? labels![i]
                      : '$i';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
        ),
      ),
    );
  }
}

int _max(int a, int b) => a > b ? a : b;

/// Registration metadata for `BarChart`.
ComponentDefinition barChartDefinition() {
  return ComponentDefinition(
    name: 'BarChart',
    description: 'multi-series bar chart',
    schema: Schema.object(
      properties: {
        'series': Schema.list(
          description:
              'array of {name: string, values: array of numbers} objects. '
              '`data` is accepted as an alias for `values`.',
        ),
        'labels': Schema.list(
          description: 'array of x-axis label strings, one per data point',
        ),
      },
      required: ['series'],
    ),
  );
}

/// Renders `BarChart`.
Widget renderBarChart(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  final raw = (props['series'] as List<Object?>?) ?? const <Object?>[];
  final series = <({String name, List<num> values})>[
    for (final s in raw)
      if (_coerceSeriesMap(s) case final seriesMap?)
        (
          name: seriesMap['name']?.toString() ?? '',
          values: _coerceNumList(seriesMap['values'] ?? seriesMap['data']),
        ),
  ];
  final labels = (props['labels'] as List<Object?>?)
      ?.whereType<String>()
      .toList();
  return BarChartWidget(series: series, labels: labels);
}

Map<String, Object?>? _coerceSeriesMap(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key case final String key) key: entry.value,
  };
}

List<num> _coerceNumList(Object? value) {
  if (value is! List<Object?>) return const <num>[];
  return value.whereType<num>().toList(growable: false);
}

String _formatTooltipValue(double value) {
  final rounded = value.toStringAsFixed(2);
  return rounded.contains('.')
      ? rounded.replaceFirst(RegExp(r'\.?0+$'), '')
      : rounded;
}
