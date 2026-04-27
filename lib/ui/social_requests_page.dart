import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/social_help_request.dart';

/// Заявки соцпомощи: студент создаёт; соцпед и замдиректор ведут статус.
class SocialRequestsPage extends StatefulWidget {
  const SocialRequestsPage({
    super.key,
    required this.user,
    required this.role,
  });

  final AppUser user;
  final UserRole role;

  @override
  State<SocialRequestsPage> createState() => _SocialRequestsPageState();
}

class _SocialRequestsPageState extends State<SocialRequestsPage> {
  List<SocialHelpRequest>? _list;
  Object? _error;
  bool _loading = true;

  bool get _isStaff =>
      widget.role == UserRole.socialPedagogue || widget.role == UserRole.deputyDirector;

  bool get _canCreate => widget.role == UserRole.student;

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
      final list = await AppDatabase.instance.listSocialRequests(
        viewerId: widget.user.id,
        viewerRole: widget.role,
      );
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

  Future<void> _openCreate() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая заявка'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Тема',
                  hintText: 'Кратко, о чём заявка',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ситуация',
                  alignLabelWithHint: true,
                  hintText: 'Опишите, что произошло и чем нужна помощь',
                ),
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await AppDatabase.instance.createSocialRequest(
      authorId: widget.user.id,
      title: titleCtrl.text,
      body: bodyCtrl.text,
    );
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка отправлена')),
    );
    await _load();
  }

  Future<void> _openStaffSheet(SocialHelpRequest r) async {
    var chosen = r.status;
    final replyCtrl = TextEditingController(text: r.staffReply ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.title, style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(r.body, style: Theme.of(ctx).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Text('Статус', style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<SocialRequestStatus>(
                      segments: SocialRequestStatus.values
                          .map(
                            (s) => ButtonSegment<SocialRequestStatus>(
                              value: s,
                              label: Text(s.labelRu, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      selected: <SocialRequestStatus>{chosen},
                      onSelectionChanged: (set) => setModal(() => chosen = set.first),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: replyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий для студента (необязательно)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final updateErr = await AppDatabase.instance.updateSocialRequestByStaff(
                          requestId: r.id,
                          staffRole: widget.role,
                          newStatus: chosen,
                          staffReply: replyCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        if (updateErr != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(updateErr)));
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    replyCtrl.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
      await _load();
    }
  }

  Color _statusColor(SocialRequestStatus s, ColorScheme scheme) {
    switch (s) {
      case SocialRequestStatus.pending:
        return scheme.tertiary;
      case SocialRequestStatus.inProgress:
        return scheme.primary;
      case SocialRequestStatus.resolved:
        return scheme.secondary;
    }
  }

  String _dateRu(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day.$m.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$_error', textAlign: TextAlign.center),
            ),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final list = _list ?? <SocialHelpRequest>[];
    return Scaffold(
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volunteer_activism_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _canCreate ? 'Заявок пока нет.' : 'Нет заявок для отображения.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_canCreate) ...[
                    const SizedBox(height: 8),
                    const Text('Нажмите «+», чтобы описать ситуацию.'),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final col = _statusColor(r.status, scheme);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: _isStaff ? () => _openStaffSheet(r) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    r.status.labelRu,
                                    style: TextStyle(color: scheme.onSecondary, fontSize: 12),
                                  ),
                                  backgroundColor: col.withValues(alpha: 0.35),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            if (_isStaff) ...[
                              const SizedBox(height: 4),
                              Text(
                                'От: ${r.authorName}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(r.body, style: Theme.of(context).textTheme.bodyMedium),
                            if (r.staffReply != null && r.staffReply!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Ответ специалиста:',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(r.staffReply!, style: Theme.of(context).textTheme.bodySmall),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Создано: ${_dateRu(r.createdAtMs)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (_isStaff)
                              Text(
                                'Нажмите карточку, чтобы изменить статус',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
