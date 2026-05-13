// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:openui_core/openui_core.dart';

/// `LineChart(series, labels?)` — multi-series line chart. `series` is
/// a list of `{name: String, values: List<num>}`.
class LineChartWidget extends StatelessWidget {
  /// Creates a [LineChartWidget].
  const LineChartWidget({
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
    final pointCount = series.map((s) => s.values.length).fold(0, math.max);
    if (pointCount == 0) return SizedBox(height: height);
    final yValues = <double>[
      for (final s in series) ...s.values.map((value) => value.toDouble()),
    ];
    final minValue = yValues.reduce(math.min);
    final maxValue = yValues.reduce(math.max);
    final yRange = maxValue - minValue;
    final yPadding = yRange == 0
        ? (maxValue == 0 ? 1.0 : maxValue.abs() * 0.1)
        : yRange * 0.08;
    final minY = minValue - yPadding;
    final maxY = maxValue + yPadding;

    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
    ];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (pointCount - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: <LineChartBarData>[
            for (var s = 0; s < series.length; s++)
              LineChartBarData(
                isCurved: true,
                preventCurveOverShooting: true,
                color: palette[s % palette.length],
                dotData: const FlDotData(show: false),
                spots: <FlSpot>[
                  for (var i = 0; i < series[s].values.length; i++)
                    FlSpot(i.toDouble(), series[s].values[i].toDouble()),
                ],
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots
                    .map((spot) {
                      final seriesName = series[spot.barIndex].name;
                      final value = _formatTooltipValue(spot.y);
                      return LineTooltipItem(
                        '$seriesName\n$value',
                        TextStyle(
                          color: scheme.onInverseSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      );
                    })
                    .toList(growable: false);
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if ((value - value.roundToDouble()).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }
                  final i = value.round();
                  if (i < 0 || i >= pointCount) {
                    return const SizedBox.shrink();
                  }
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

/// Registration for `LineChart`.
Component<Widget> lineChartComponent() {
  return Component<Widget>(
    name: 'LineChart',
    description: 'multi-series line chart',
    schema: Schema.object(
      properties: {
        'series': Schema.list(
          items: Schema.object(
            properties: {
              'name': Schema.string(),
              'values': Schema.list(items: Schema.number()),
            },
          ),
        ),
        'labels': Schema.list(items: Schema.string()),
      },
      required: ['series'],
    ),
    render: (ctx, props, renderNode, id) {
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
      return LineChartWidget(series: series, labels: labels);
    },
  );
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
