import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/garden_providers.dart';
import '../camera/camera_page.dart';
import '../controls/controls_page.dart';
import '../dashboard/dashboard_page.dart';
import '../history/history_page.dart';
import '../rooms/rooms_page.dart';
import '../settings/settings_page.dart';

/// Bottom-nav shell holding the tabs. Each tab is the existing page; the shell
/// only swaps the body and keeps a sign-out action in scope.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    RoomsPage(),
    ControlsPage(),
    CameraPage(),
    SettingsPage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Garden'),
          NavigationDestination(icon: Icon(Icons.meeting_room), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Controls'),
          NavigationDestination(icon: Icon(Icons.videocam), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Auto'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'History'),
        ],
      ),
    );
  }
}

/// A reusable sign-out button (drop into any AppBar's actions).
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(authServiceProvider).signOut(),
    );
  }
}
