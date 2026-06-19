import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';

class ControlsPage extends ConsumerWidget {
  const ControlsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stateProvider);
    final service = ref.read(gardenServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Controls')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // The switch reflects /state (what the Pi confirms), so it stays
            // honest even if a relay fails or the Pi is offline.
            SwitchListTile(
              secondary: const Icon(Icons.water),
              title: const Text('Water pump'),
              subtitle: Text(s.pump ? 'ON' : 'OFF'),
              value: s.pump,
              onChanged: (v) => service.setPump(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lightbulb),
              title: const Text('Grow light'),
              subtitle: Text(s.light ? 'ON' : 'OFF'),
              value: s.light,
              onChanged: (v) => service.setLight(v),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                s.cameraOnline ? Icons.videocam : Icons.videocam_off,
                color: s.cameraOnline ? Colors.green : Colors.grey,
              ),
              title: const Text('Live camera'),
              subtitle: Text(s.cameraOnline ? 'Online' : 'Offline'),
              // TODO: open WebRTC live view (milestone 6).
            ),
          ],
        ),
      ),
    );
  }
}
