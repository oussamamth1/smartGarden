import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room.dart';
import '../../providers/garden_providers.dart';
import 'room_detail_page.dart';

/// Lists the user's rooms with live temperature; add/rename/delete from here.
class RoomsPage extends ConsumerWidget {
  const RoomsPage({super.key});

  Future<String?> _nameDialog(BuildContext context, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? 'New room' : 'Rename room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Room name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final service = ref.read(gardenServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _nameDialog(context);
          if (name != null && name.isNotEmpty) await service.addRoom(name);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No rooms yet — tap "Add room" to create one.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final room in list)
                _RoomTile(
                  room: room,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomDetailPage(room: room),
                    ),
                  ),
                  onRename: () async {
                    final name =
                        await _nameDialog(context, initial: room.name);
                    if (name != null && name.isNotEmpty) {
                      await service.renameRoom(room.id, name);
                    }
                  },
                  onDelete: () => service.deleteRoom(room.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomTile extends ConsumerWidget {
  const _RoomTile({
    required this.room,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Room room;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(roomTelemetryProvider(room.id));
    final temp = telemetry.asData?.value.temperature;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.meeting_room, color: Colors.green),
        title: Text(room.name),
        subtitle: Text(temp == null ? '—' : '${temp.toStringAsFixed(1)} °C'),
        onTap: onOpen,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') onRename();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
