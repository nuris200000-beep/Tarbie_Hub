import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/hub_feed_entry.dart';
import '../utils/presence_format.dart';
import '../widgets/role_badges.dart';
import '../widgets/user_avatar.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.currentUser,
    required this.activeRole,
  });

  final AppUser currentUser;
  final UserRole activeRole;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<HubFeedEntry>? _items;
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
      final list = await AppDatabase.instance.listFeedEntries();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  bool _canDelete(HubFeedEntry entry) {
    return widget.currentUser.isAdmin ||
        widget.activeRole == UserRole.deputyDirector ||
        entry.event.authorId == widget.currentUser.id;
  }

  Future<void> _deleteEvent(HubFeedEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить мероприятие?'),
        content: const Text('Мероприятие и связанные уведомления будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final err = await AppDatabase.instance.deleteEvent(
      eventId: entry.event.id,
      actorId: widget.currentUser.id,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Мероприятие удалено')),
    );
    await _load();
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
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Обновить')),
          ],
        ),
      );
    }
    final items = _items ?? <HubFeedEntry>[];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Пока нет записей', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Мероприятия кураторов и персонала появятся здесь для всех.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Обновить')),
          ],
        ),
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final e = items[i];
          final ev = e.event;
          final presence = formatLastSeenRu(e.authorLastSeenMs, nowMs: now);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ev.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dateLabel(ev.createdAtMs),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_canDelete(e))
                            IconButton(
                              tooltip: 'Удалить мероприятие',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _deleteEvent(e),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(ev.description, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.label_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                      Text(ev.valueTag, style: Theme.of(context).textTheme.bodyMedium),
                      Icon(Icons.groups_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                      Text(ev.groupName, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Автор', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        name: ev.authorName,
                        imagePath: e.authorAvatarPath,
                        radius: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.authorName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            RoleChipsRow(roles: e.authorRoles, isAdmin: e.authorIsAdmin),
                            const SizedBox(height: 6),
                            Text(
                              '${e.authorStatus.labelRu} • $presence',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dateLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}
