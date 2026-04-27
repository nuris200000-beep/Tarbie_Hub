import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/student_group.dart';
import '../widgets/role_badges.dart';
import '../widgets/user_avatar.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<AppUser>? _users;
  List<StudentGroup>? _groups;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reloadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final users = await AppDatabase.instance.listUsers();
      final groups = await AppDatabase.instance.listStudentGroups();
      if (!mounted) return;
      setState(() {
        _users = users;
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _reloadUsers() async {
    final list = await AppDatabase.instance.listUsers();
    if (mounted) setState(() => _users = list);
  }

  Future<void> _reloadGroups() async {
    final list = await AppDatabase.instance.listStudentGroups();
    if (mounted) setState(() => _groups = list);
  }

  Future<void> _confirmDelete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Будет удалён: ${u.login} (${u.name})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await AppDatabase.instance.deleteUser(
      userId: u.id,
      actorId: widget.currentUser.id,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Пользователь ${u.login} удалён')),
    );
    await _reloadUsers();
  }

  Future<void> _editRoles(AppUser u) async {
    final selected = <UserRole>{...u.roles};
    var isAdmin = u.isAdmin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Роли: ${u.login}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Выберите одну или несколько ролей:'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: UserRole.values.map((role) {
                        final on = selected.contains(role);
                        return FilterChip(
                          label: Text(role.label),
                          selected: on,
                          onSelected: (v) {
                            setLocal(() {
                              if (v) {
                                selected.add(role);
                              } else {
                                selected.remove(role);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Администратор'),
                      subtitle: const Text('Доступ к админ-панели'),
                      value: isAdmin,
                      onChanged: (v) => setLocal(() => isAdmin = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужна хотя бы одна роль')),
      );
      return;
    }
    final err = await AppDatabase.instance.updateUserRolesAndAdmin(
      targetUserId: u.id,
      roles: selected.toList(),
      isAdmin: isAdmin,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Роли обновлены')));
    await _reloadUsers();
  }

  Future<void> _addGroup() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая группа'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Добавить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await AppDatabase.instance.addStudentGroup(ctrl.text);
    ctrl.dispose();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа добавлена')));
    await _reloadGroups();
  }

  Future<void> _deleteGroup(StudentGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text('«${g.name}» — у пользователей в этой группе поле группы будет сброшено.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await AppDatabase.instance.deleteStudentGroup(g.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа удалена')));
    await _reloadGroups();
    await _reloadUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.isAdmin) {
      return const Center(child: Text('Доступ только для администратора'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reloadAll, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final users = _users ?? <AppUser>[];
    final groups = _groups ?? <StudentGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Админ-панель', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Пользователи'),
            Tab(text: 'Группы'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Пользователи, роли и удаление учётных записей.'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final u = users[i];
                          return ListTile(
                            leading: UserAvatar(
                              name: u.name,
                              imagePath: u.avatarPath,
                              radius: 22,
                            ),
                            title: Text(u.login),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.name),
                                if (u.email != null && u.email!.isNotEmpty)
                                  Text('Email: ${u.email}', style: Theme.of(context).textTheme.bodySmall),
                                if (u.groupName != null && u.groupName!.isNotEmpty)
                                  Text('Группа: ${u.groupName}', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 6),
                                RoleChipsRow(roles: u.roles, isAdmin: u.isAdmin),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Роли',
                                  onPressed: () => _editRoles(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Удалить',
                                  onPressed: () => _confirmDelete(u),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Группы для регистрации студентов. Добавьте хотя бы одну группу.'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _addGroup,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить группу'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: groups.isEmpty
                          ? const Center(child: Text('Список пуст — нажмите «Добавить группу»'))
                          : ListView.separated(
                              itemCount: groups.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final g = groups[i];
                                return ListTile(
                                  title: Text(g.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Удалить',
                                    onPressed: () => _deleteGroup(g),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
