import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';
import '../device_status/device_offline_banner.dart';
import '../home/home_page.dart' show SignOutButton;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌱 Garden Pi'),
        actions: const [SignOutButton()],
      ),
      body: Column(
        children: [
          const DeviceOfflineBanner(),
          Expanded(
            child: telemetry.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (t) => GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                childAspectRatio: 1.3,
                children: [
                  _SensorCard('Temperature', t.temperature, '°C', Icons.thermostat),
                  _SensorCard('Humidity', t.humidity, '%', Icons.water_drop),
                  _SensorCard('Soil', t.soilMoisture, '%', Icons.grass),
                  _SensorCard('Light', t.lightLevel, 'lux', Icons.light_mode),
                  _SensorCard('Pressure', t.pressure, 'hPa', Icons.speed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard(this.label, this.value, this.unit, this.icon);

  final String label;
  final double? value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        // FittedBox scales the content down to fit the cell, so it can't
        // overflow regardless of grid cell size or system font scaling.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                value == null ? '--' : '${value!.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
