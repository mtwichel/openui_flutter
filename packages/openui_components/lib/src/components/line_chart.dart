// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
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
          lineBarsData: <LineChartBarData>[
            for (var s = 0; s < series.length; s++)
              LineChartBarData(
                isCurved: true,
                color: palette[s % palette.length],
                dotData: const FlDotData(show: false),
                spots: <FlSpot>[
                  for (var i = 0; i < series[s].values.length; i++)
                    FlSpot(i.toDouble(), series[s].values[i].toDouble()),
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

/// Registration for `LineChart`.
Component<Widget> lineChartComponent() {
  return defineComponent<Widget>(
    name: 'LineChart',
    description: 'multi-series line chart',
    schema: objectSchema(
      const <String, Object?>{
        'series': <String, Object?>{'type': 'array'},
        'labels': <String, Object?>{'type': 'array'},
      },
      required: const ['series'],
    ),
    render: (ctx, props, renderNode, id) {
      final raw = (props['series'] as List<Object?>?) ?? const <Object?>[];
      final series = <({String name, List<num> values})>[
        for (final s in raw)
          if (s is Map<String, Object?>)
            (
              name: s['name'] as String? ?? '',
              values: (s['values'] as List<Object?>? ?? const <Object?>[])
                  .whereType<num>()
                  .toList(),
            ),
      ];
      final labels = (props['labels'] as List<Object?>?)
          ?.whereType<String>()
          .toList();
      return LineChartWidget(series: series, labels: labels);
    },
  );
}
