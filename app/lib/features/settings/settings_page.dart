import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';

/// Edits the automation rules under /settings. The Pi reads these every
/// AUTOMATION_INTERVAL_SEC, so changes take effect within a few seconds.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final service = ref.read(gardenServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Automation')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) {
          final autoWater = s['auto_water_enabled'] == true;
          final below = (s['auto_water_below'] as num?)?.toDouble() ?? 30;
          final seconds = (s['auto_water_seconds'] as num?)?.toInt() ?? 20;
          final onTime = (s['light_schedule_on'] as String?) ?? '06:00';
          final offTime = (s['light_schedule_off'] as String?) ?? '20:00';
          final tempAlert = (s['temp_alert_above'] as num?)?.toInt() ?? 35;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionHeader('Auto-watering'),
              SwitchListTile(
                title: const Text('Enable auto-watering'),
                subtitle: const Text('Run the pump when soil is too dry'),
                value: autoWater,
                onChanged: (v) =>
                    service.updateSettings({'auto_water_enabled': v}),
              ),
              ListTile(
                title: const Text('Water below soil moisture'),
                subtitle: Slider(
                  value: below.clamp(0, 100),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${below.round()}%',
                  onChanged: autoWater
                      ? (v) => service
                          .updateSettings({'auto_water_below': v.round()})
                      : null,
                ),
                trailing: Text('${below.round()}%'),
              ),
              _StepperTile(
                label: 'Pump run time',
                value: seconds,
                unit: 's',
                step: 5,
                onChanged: (v) =>
                    service.updateSettings({'auto_water_seconds': v}),
              ),
              const Divider(),
              const _SectionHeader('Light schedule'),
              _TimeTile(
                label: 'Turn on at',
                value: onTime,
                onChanged: (v) =>
                    service.updateSettings({'light_schedule_on': v}),
              ),
              _TimeTile(
                label: 'Turn off at',
                value: offTime,
                onChanged: (v) =>
                    service.updateSettings({'light_schedule_off': v}),
              ),
              const Divider(),
              const _SectionHeader('Alerts'),
              _StepperTile(
                label: 'Temperature alert above',
                value: tempAlert,
                unit: '°C',
                step: 1,
                onChanged: (v) =>
                    service.updateSettings({'temp_alert_above': v}),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
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

class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final int step;
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
            onPressed: () => onChanged((value - step).clamp(0, 1000)),
          ),
          Text('$value$unit', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged((value + step).clamp(0, 1000)),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value; // "HH:mm"
  final ValueChanged<String> onChanged;

  TimeOfDay get _time {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontSize: 16)),
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: _time);
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          onChanged('$hh:$mm');
        }
      },
    );
  }
}
