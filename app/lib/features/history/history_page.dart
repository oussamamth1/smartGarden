import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';

/// Charts the logged readings from /history. Updates live as the Pi appends
/// new points (the provider is a stream).
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (points) {
          if (points.isEmpty) {
            return const Center(
              child: Text('No history yet — readings appear as the Pi logs them.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Chart(
                title: 'Temperature (°C)',
                color: Colors.orange,
                values: [for (final p in points) p.temperature],
              ),
              const SizedBox(height: 24),
              _Chart(
                title: 'Soil moisture (%)',
                color: Colors.brown,
                values: [for (final p in points) p.soilMoisture],
              ),
              const SizedBox(height: 24),
              _Chart(
                title: 'Humidity (%)',
                color: Colors.blue,
                values: [for (final p in points) p.humidity],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.title,
    required this.color,
    required this.values,
  });

  final String title;
  final Color color;
  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        if (values[i] != null) FlSpot(i.toDouble(), values[i]!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: spots.isEmpty
              ? const Center(child: Text('—'))
              : LineChart(
                  LineChartData(
                    titlesData: const FlTitlesData(
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        color: color,
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          // ignore: deprecated_member_use
                          color: color.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
