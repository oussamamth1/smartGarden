import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room.dart';
import '../../providers/garden_providers.dart';

/// One room: live temperature, device toggles (heater/fan/light reflecting
/// /state), and per-room climate settings.
class RoomDetailPage extends ConsumerWidget {
  const RoomDetailPage({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(roomTelemetryProvider(room.id));
    final state = ref.watch(roomStateProvider(room.id));
    final settings = ref.watch(roomSettingsProvider(room.id));
    final service = ref.read(gardenServiceProvider);

    final t = telemetry.asData?.value;
    final s = state.asData?.value ?? const RoomState();
    final cfg = settings.asData?.value ?? const {};

    final autoClimate = cfg['auto_climate_enabled'] == true;
    final target = (cfg['target_temp'] as num?)?.toInt() ?? 22;
    final tempAlert = (cfg['temp_alert_above'] as num?)?.toInt() ?? 30;

    return Scaffold(
      appBar: AppBar(title: Text(room.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live readings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Reading(Icons.thermostat, t?.temperature, '°C'),
                  _Reading(Icons.water_drop, t?.humidity, '%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Devices — reflect /state (what the Pi confirms)
          const _Header('Devices'),
          SwitchListTile(
            secondary: const Icon(Icons.local_fire_department),
            title: const Text('Heater'),
            subtitle: Text(s.heater ? 'ON' : 'OFF'),
            value: s.heater,
            onChanged: (v) => service.setRoomDevice(room.id, 'heater', v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.air),
            title: const Text('Fan'),
            subtitle: Text(s.fan ? 'ON' : 'OFF'),
            value: s.fan,
            onChanged: (v) => service.setRoomDevice(room.id, 'fan', v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb),
            title: const Text('Light'),
            subtitle: Text(s.light ? 'ON' : 'OFF'),
            value: s.light,
            onChanged: (v) => service.setRoomDevice(room.id, 'light', v),
          ),

          const Divider(),
          const _Header('Climate automation'),
          SwitchListTile(
            title: const Text('Auto climate'),
            subtitle: const Text('Heater/fan hold the target temperature'),
            value: autoClimate,
            onChanged: (v) =>
                service.updateRoomSettings(room.id, {'auto_climate_enabled': v}),
          ),
          _Stepper(
            label: 'Target temperature',
            value: target,
            unit: '°C',
            onChanged: (v) =>
                service.updateRoomSettings(room.id, {'target_temp': v}),
          ),
          _Stepper(
            label: 'Temperature alert above',
            value: tempAlert,
            unit: '°C',
            onChanged: (v) =>
                service.updateRoomSettings(room.id, {'temp_alert_above': v}),
          ),
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading(this.icon, this.value, this.unit);
  final IconData icon;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.green),
        const SizedBox(height: 6),
        Text(
          value == null ? '--' : '${value!.toStringAsFixed(1)} $unit',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onChanged((value - 1).clamp(0, 100)),
          ),
          Text('$value$unit', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged((value + 1).clamp(0, 100)),
          ),
        ],
      ),
    );
  }
}
