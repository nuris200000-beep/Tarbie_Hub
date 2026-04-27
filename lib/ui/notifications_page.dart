import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/hub_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.user});

  final AppUser user;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<HubNotification>? _list;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppDatabase.instance.listNotifications(widget.user.id);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _tap(HubNotification n) async {
    if (!n.read) {
      await AppDatabase.instance.markNotificationRead(n.id, widget.user.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error'),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final list = _list ?? <HubNotification>[];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text('Нет уведомлений', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Обновить')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = list[i];
          return ListTile(
            tileColor: n.read
                ? null
                : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
            leading: Icon(
              n.read ? Icons.notifications_none : Icons.notifications_active,
              color: n.read ? null : Theme.of(context).colorScheme.primary,
            ),
            title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w600)),
            subtitle: Text(n.body),
            trailing: Text(
              _time(n.createdAtMs),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _tap(n),
          );
        },
      ),
    );
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, "0")}.${d.month.toString().padLeft(2, "0")} '
        '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
  }
}
