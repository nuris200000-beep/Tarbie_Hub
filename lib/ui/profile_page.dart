import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/profile_status.dart';
import '../utils/presence_format.dart';
import '../widgets/role_badges.dart';
import '../widgets/user_avatar.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.role,
    required this.onUserUpdated,
  });

  final AppUser user;
  final UserRole role;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _name;
  ProfileStatus _status = ProfileStatus.online;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _status = widget.user.status;
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.name != widget.user.name) {
      _name.text = widget.user.name;
      _status = widget.user.status;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _reloadUser() async {
    final u = await AppDatabase.instance.getUserById(widget.user.id);
    if (u != null && mounted) widget.onUserUpdated(u);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final path = await AppDatabase.instance.saveAvatarFromFile(widget.user.id, x.path);
      if (path != null) {
        await AppDatabase.instance.updateProfile(userId: widget.user.id, avatarPath: path);
      }
      await _reloadUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Фото: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _saving = true);
    try {
      await AppDatabase.instance.clearAvatar(widget.user.id);
      await _reloadUser();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await AppDatabase.instance.updateProfile(
        userId: widget.user.id,
        displayName: _name.text,
        status: _status,
      );
      await AppDatabase.instance.touchPresence(widget.user.id);
      await _reloadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль сохранён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final now = DateTime.now().millisecondsSinceEpoch;
    final activity = formatLastSeenRu(u.lastSeenMs, nowMs: now);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatar(
                        name: u.name,
                        imagePath: u.avatarPath,
                        radius: 56,
                        fontSize: 40,
                      ),
                      if (_saving)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x66000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _saving ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Фото'),
                      ),
                      if (u.avatarPath != null && u.avatarPath!.isNotEmpty)
                        TextButton(
                          onPressed: _saving ? null : _removePhoto,
                          child: const Text('Убрать фото'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Активность: $activity',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Обновляется, пока приложение открыто (пульс присутствия).',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Данные', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('Логин: ${u.login}', style: Theme.of(context).textTheme.bodyLarge),
                  if (u.email != null && u.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Email: ${u.email}', style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  if (u.groupName != null && u.groupName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Группа: ${u.groupName}', style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Отображаемое имя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Статус', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ProfileStatus.values.map((s) {
                      return ChoiceChip(
                        label: Text(s.labelRu),
                        selected: _status == s,
                        onSelected: _saving
                            ? null
                            : (v) {
                                if (v) setState(() => _status = s);
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Статус виден другим в ленте рядом с вашими мероприятиями.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text('Роли', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RoleChipsRow(roles: u.roles, isAdmin: u.isAdmin),
                  const SizedBox(height: 8),
                  Text('Контур сейчас: ${widget.role.label}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
