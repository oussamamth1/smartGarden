import 'package:flutter/material.dart';

/// Step-by-step guide shown when the Pi is offline: how the user connects the
/// device to their WiFi via the on-device setup hotspot ("GardenPi-Setup").
class WifiSetupHelpPage extends StatelessWidget {
  const WifiSetupHelpPage({super.key});

  static const _steps = <(IconData, String, String)>[
    (
      Icons.power_settings_new,
      'Power on the device',
      'Plug in the Garden Pi and wait about a minute for it to start up.',
    ),
    (
      Icons.wifi_tethering,
      'Find the setup network',
      'If the device isn\'t connected to WiFi yet, it creates its own network '
          'called "GardenPi-Setup".',
    ),
    (
      Icons.phone_iphone,
      'Connect your phone to it',
      'On your phone: Settings → WiFi → tap "GardenPi-Setup" to join it.',
    ),
    (
      Icons.list_alt,
      'Choose your home WiFi',
      'A setup page opens automatically. Pick your home WiFi network and enter '
          'its password, then submit.',
    ),
    (
      Icons.check_circle,
      'Done',
      'The device joins your WiFi and comes online here within a minute. It '
          'reconnects automatically next time — you only do this once.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect your device to WiFi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Set up the Garden Pi on your WiFi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _steps.length; i++)
            _StepTile(number: i + 1, data: _steps[i]),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tip: use a 2.4 GHz WiFi network and keep the device within '
                'range of your router. The "GardenPi-Setup" network only appears '
                'when the device has no WiFi configured.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.data});

  final int number;
  final (IconData, String, String) data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            child: Text(
              '$number',
              style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(data.$1, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.$2,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(data.$3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
