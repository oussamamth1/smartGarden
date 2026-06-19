import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';
import 'wifi_setup_help_page.dart';

/// Shows a warning banner when the Pi hasn't reported recently (offline / not
/// yet on WiFi), with a shortcut to the WiFi setup guide. Renders nothing while
/// the device is online.
class DeviceOfflineBanner extends ConsumerWidget {
  const DeviceOfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(piOnlineProvider).asData?.value ?? true;
    if (online) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WifiSetupHelpPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device offline',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Not receiving data. Tap to set up the device\'s WiFi.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
