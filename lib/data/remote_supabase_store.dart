import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/password_policy.dart';
import '../models/app_user.dart';
import '../models/student_group.dart';
import '../models/hub_event.dart';
import '../models/hub_feed_entry.dart';
import '../models/hub_notification.dart';
import '../models/profile_status.dart';
import '../models/social_help_request.dart';
import 'auth_crypto.dart';

/// Облачные данные (одна БД на все устройства).
class RemoteSupabaseStore {
  RemoteSupabaseStore._();
  static final RemoteSupabaseStore instance = RemoteSupabaseStore._();

  SupabaseClient get _c => Supabase.instance.client;

  static const String _users = 'tarbie_users';
  static const String _events = 'tarbie_events';
  static const String _notifications = 'tarbie_notifications';
  static const String _groups = 'tarbie_groups';
  static const String _socialRequests = 'tarbie_social_requests';
  static const String _bucket = 'avatars';

  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  AppUser _userFromRow(Map<String, dynamic> row, {Map<int, String>? groupNames}) {
    final lastSeen = row['last_seen_ms'];
    final gidRaw = row['group_id'];
    final int? gid = gidRaw == null ? null : _asInt(gidRaw);
    final String? gn =
        row['group_name'] as String? ?? (gid != null && groupNames != null ? groupNames[gid] : null);
    return AppUser(
      id: _asInt(row['id']),
      login: row['login']! as String,
      name: row['display_name']! as String,
      roles: AppUser.rolesFromStored(row['roles']! as String),
      isAdmin: _asInt(row['is_admin']) == 1,
      avatarPath: row['avatar_path'] as String?,
      status: ProfileStatus.fromStored(row['status'] as String?),
      lastSeenMs: lastSeen is int ? lastSeen : (lastSeen is num ? lastSeen.toInt() : 0),
      email: row['email'] as String?,
      groupName: gn,
    );
  }

  Future<Map<int, String>> _groupNameMap() async {
    final list = await _c.from(_groups).select('id,name').order('name');
    final m = <int, String>{};
    for (final raw in list as List<dynamic>) {
      final r = Map<String, dynamic>.from(raw as Map);
      m[_asInt(r['id'])] = r['name']! as String;
    }
    return m;
  }

  Future<String?> register({
    required String login,
    required String displayName,
    required String email,
    required int groupId,
    required String password,
  }) async {
    final trimmedLogin = login.trim().toLowerCase();
    if (trimmedLogin.length < 3) return 'Логин не короче 3 символов';
    if (displayName.trim().length < 2) return 'Введите имя';
    final pwdErr = PasswordPolicy.validate(password);
    if (pwdErr != null) return pwdErr;
    final emailLower = email.trim().toLowerCase();
    if (emailLower.length < 5 || !emailLower.contains('@')) {
      return 'Введите корректный email';
    }

    final g = await _c.from(_groups).select('id').eq('id', groupId).limit(1).maybeSingle();
    if (g == null) return 'Выберите группу из списка';

    final salt = AuthCrypto.randomSalt();
    final hash = AuthCrypto.hashPassword(password, salt);
    final roles = AppUser.rolesToStored(<UserRole>[UserRole.student]);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _c.from(_users).insert(<String, dynamic>{
        'login': trimmedLogin,
        'display_name': displayName.trim(),
        'email': emailLower,
        'group_id': groupId,
        'password_hash': hash,
        'salt': salt,
        'roles': roles,
        'is_admin': 0,
        'status': ProfileStatus.online.name,
        'last_seen_ms': now,
      });
    } on PostgrestException catch (e) {
      final code = e.code?.toString();
      final msg = e.message;
      if (code == '23505' ||
          msg.contains('duplicate') ||
          msg.contains('unique') ||
          msg.contains('Unique')) {
        if (msg.toLowerCase().contains('email')) {
          return 'Этот email уже зарегистрирован';
        }
        return 'Такой логин уже занят';
      }
      return 'Ошибка регистрации: $msg';
    } catch (e) {
      return 'Ошибка регистрации: $e';
    }
    return null;
  }

  Future<AppUser?> login(String login, String password) async {
    final key = login.trim().toLowerCase();
    final rows = await _c.from(_users).select().eq('login', key).limit(1).maybeSingle();
    if (rows == null) return null;
    final row = Map<String, dynamic>.from(rows);
    final salt = row['salt']! as String;
    final hash = AuthCrypto.hashPassword(password, salt);
    if (hash != row['password_hash']) return null;
    final user = _userFromRow(row);
    await touchPresence(user.id);
    return getUserById(user.id);
  }

  Future<AppUser?> getUserById(int id) async {
    final rows = await _c.from(_users).select().eq('id', id).limit(1).maybeSingle();
    if (rows == null) return null;
    final map = Map<String, dynamic>.from(rows);
    final gmap = await _groupNameMap();
    return _userFromRow(map, groupNames: gmap);
  }

  Future<void> touchPresence(int userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _c.from(_users).update(<String, dynamic>{'last_seen_ms': now}).eq('id', userId);
  }

  Future<String?> updateProfile({
    required int userId,
    String? displayName,
    String? avatarPath,
    ProfileStatus? status,
  }) async {
    final map = <String, dynamic>{};
    if (displayName != null) map['display_name'] = displayName.trim();
    if (avatarPath != null) map['avatar_path'] = avatarPath;
    if (status != null) map['status'] = status.name;
    if (map.isEmpty) return null;
    await _c.from(_users).update(map).eq('id', userId);
    return null;
  }

  Future<String?> clearAvatar(int userId) async {
    final u = await getUserById(userId);
    final path = u?.avatarPath;
    if (path != null && path.isNotEmpty) {
      try {
        if (path.startsWith('http')) {
          final uri = Uri.parse(path);
          final segs = uri.pathSegments;
          final i = segs.indexOf(_bucket);
          if (i >= 0 && i + 1 < segs.length) {
            final objectPath = segs.sublist(i + 1).join('/');
            if (objectPath.isNotEmpty) {
              await _c.storage.from(_bucket).remove(<String>[objectPath]);
            }
          }
        } else {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
    }
    await _c.from(_users).update(<String, dynamic>{'avatar_path': null}).eq('id', userId);
    return null;
  }

  Future<String?> saveAvatarFromFile(int userId, String pickedFilePath) async {
    final bytes = await File(pickedFilePath).readAsBytes();
    final ext = pickedFilePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final objectPath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    await _c.storage.from(_bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );
    final url = _c.storage.from(_bucket).getPublicUrl(objectPath);
    return url;
  }

  /// Вводится логин; код уходит на email, указанный при регистрации.
  Future<String?> requestPasswordResetForLogin(String login) async {
    final key = login.trim().toLowerCase();
    if (key.length < 3) return 'Введите логин';
    final rows = await _c
        .from(_users)
        .select('id,email')
        .eq('login', key)
        .limit(1)
        .maybeSingle();
    if (rows == null) return 'Пользователь с таким логином не найден';
    final row = Map<String, dynamic>.from(rows);
    final email = (row['email'] as String?)?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return 'Для этого логина не задан email. Обратитесь к администратору.';
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final expires = DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch;
    await _c.from(_users).update(<String, dynamic>{
      'reset_code': code,
      'reset_expires_ms': expires,
    }).eq('id', _asInt(row['id']));

    try {
      await _c.functions.invoke(
        'send-reset-code',
        body: <String, dynamic>{'email': email, 'code': code},
      );
    } catch (e) {
      return 'Код создан, но письмо не отправлено: $e. '
          'Задеплойте Edge Function `send-reset-code` и секрет RESEND_API_KEY (см. supabase/README).';
    }
    return null;
  }

  Future<String?> completePasswordReset({
    required String login,
    required String code,
    required String newPassword,
  }) async {
    final pwdErr = PasswordPolicy.validate(newPassword);
    if (pwdErr != null) return pwdErr;
    final key = login.trim().toLowerCase();
    final rows = await _c.from(_users).select().eq('login', key).limit(1).maybeSingle();
    if (rows == null) return 'Пользователь не найден';
    final row = Map<String, dynamic>.from(rows);
    final stored = row['reset_code'] as String?;
    final exp = row['reset_expires_ms'];
    final expMs = exp is int ? exp : (exp is num ? exp.toInt() : null);
    if (stored == null || expMs == null) return 'Сначала запросите код сброса';
    if (DateTime.now().millisecondsSinceEpoch > expMs) return 'Код истёк, запросите новый';
    if (stored != code.trim()) return 'Неверный код';

    final salt = AuthCrypto.randomSalt();
    final hash = AuthCrypto.hashPassword(newPassword, salt);
    await _c.from(_users).update(<String, dynamic>{
      'password_hash': hash,
      'salt': salt,
      'reset_code': null,
      'reset_expires_ms': null,
    }).eq('id', _asInt(row['id']));
    return null;
  }

  Future<List<AppUser>> listUsers() async {
    final gmap = await _groupNameMap();
    final list = await _c.from(_users).select().order('login');
    final out = <AppUser>[];
    for (final raw in list as List<dynamic>) {
      out.add(_userFromRow(Map<String, dynamic>.from(raw as Map), groupNames: gmap));
    }
    return out;
  }

  Future<List<StudentGroup>> listStudentGroups() async {
    final list = await _c.from(_groups).select().order('name');
    return (list as List<dynamic>)
        .map(
          (raw) {
            final r = Map<String, dynamic>.from(raw as Map);
            return StudentGroup(id: _asInt(r['id']), name: r['name']! as String);
          },
        )
        .toList();
  }

  Future<String?> addStudentGroup(String name) async {
    final t = name.trim();
    if (t.length < 2) return 'Название группы не короче 2 символов';
    try {
      await _c.from(_groups).insert(<String, dynamic>{'name': t});
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('duplicate') || msg.contains('unique') || msg.contains('Unique')) {
        return 'Такая группа уже есть';
      }
      return 'Не удалось добавить группу: $msg';
    }
    return null;
  }

  Future<String?> deleteStudentGroup(int groupId) async {
    await _c.from(_users).update(<String, dynamic>{'group_id': null}).eq('group_id', groupId);
    await _c.from(_groups).delete().eq('id', groupId);
    return null;
  }

  Future<String?> deleteUser({required int userId, required int actorId}) async {
    if (userId == actorId) return 'Нельзя удалить свою учётную запись';
    await _c.from(_users).delete().eq('id', userId);
    return null;
  }

  Future<String?> updateUserRolesAndAdmin({
    required int targetUserId,
    required List<UserRole> roles,
    required bool isAdmin,
  }) async {
    if (roles.isEmpty) return 'Нужна хотя бы одна роль';
    final sorted = List<UserRole>.of(roles)
      ..sort((UserRole a, UserRole b) => a.index.compareTo(b.index));
    await _c.from(_users).update(<String, dynamic>{
      'roles': AppUser.rolesToStored(sorted),
      'is_admin': isAdmin ? 1 : 0,
    }).eq('id', targetUserId);
    return null;
  }

  Future<List<HubFeedEntry>> listFeedEntries() async {
    final events = await _c.from(_events).select().order('created_at_ms', ascending: false);
    final out = <HubFeedEntry>[];
    for (final raw in events as List<dynamic>) {
      final e = Map<String, dynamic>.from(raw as Map);
      final authorId = _asInt(e['author_id']);
      final author = await _c.from(_users).select().eq('id', authorId).limit(1).maybeSingle();
      if (author == null) continue;
      final u = Map<String, dynamic>.from(author);
      final lastSeen = u['last_seen_ms'];
      out.add(
        HubFeedEntry(
          event: HubEvent(
            id: _asInt(e['id']),
            title: e['title']! as String,
            description: e['description']! as String,
            valueTag: e['value_tag']! as String,
            groupName: e['group_name']! as String,
            authorId: authorId,
            authorName: u['display_name']! as String,
            createdAtMs: _asInt(e['created_at_ms']),
          ),
          authorRoles: AppUser.rolesFromStored(u['roles']! as String),
          authorIsAdmin: _asInt(u['is_admin']) == 1,
          authorLastSeenMs: lastSeen is int ? lastSeen : (lastSeen is num ? lastSeen.toInt() : 0),
          authorStatus: ProfileStatus.fromStored(u['status'] as String?),
          authorAvatarPath: u['avatar_path'] as String?,
        ),
      );
    }
    return out;
  }

  Future<int> createEventAndNotifyAll({
    required int authorId,
    required String title,
    required String description,
    required String valueTag,
    required String groupName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ins = await _c
        .from(_events)
        .insert(<String, dynamic>{
          'title': title.trim(),
          'description': description.trim(),
          'value_tag': valueTag.trim(),
          'group_name': groupName.trim(),
          'author_id': authorId,
          'created_at_ms': now,
        })
        .select('id')
        .single();
    final eventId = _asInt(ins['id']);
    final users = await _c.from(_users).select('id');
    for (final raw in users as List<dynamic>) {
      final uid = _asInt((raw as Map)['id']);
      await _c.from(_notifications).insert(<String, dynamic>{
        'user_id': uid,
        'title': 'Новое мероприятие',
        'body': title.trim(),
        'created_at_ms': now,
        'read': 0,
        'event_id': eventId,
      });
    }
    return eventId;
  }

  Future<String?> deleteEvent({
    required int eventId,
    required int actorId,
  }) async {
    final actorRow = await _c
        .from(_users)
        .select('id,is_admin,roles')
        .eq('id', actorId)
        .limit(1)
        .maybeSingle();
    if (actorRow == null) return 'Пользователь не найден';
    final actor = Map<String, dynamic>.from(actorRow);

    final eventRow = await _c
        .from(_events)
        .select('id,author_id')
        .eq('id', eventId)
        .limit(1)
        .maybeSingle();
    if (eventRow == null) return 'Мероприятие не найдено';
    final event = Map<String, dynamic>.from(eventRow);
    final authorId = _asInt(event['author_id']);

    final isAdmin = _asInt(actor['is_admin']) == 1;
    final roles = AppUser.rolesFromStored((actor['roles'] as String?) ?? '');
    final canDelete =
        isAdmin || roles.contains(UserRole.deputyDirector) || authorId == actorId;
    if (!canDelete) return 'Недостаточно прав для удаления мероприятия';

    await _c.from(_events).delete().eq('id', eventId);
    await _c.from(_notifications).delete().eq('event_id', eventId);
    return null;
  }

  Future<List<HubNotification>> listNotifications(int userId) async {
    final list = await _c
        .from(_notifications)
        .select()
        .eq('user_id', userId)
        .order('created_at_ms', ascending: false);
    return (list as List<dynamic>)
        .map(
          (raw) {
            final r = Map<String, dynamic>.from(raw as Map);
            return HubNotification(
              id: _asInt(r['id']),
              userId: _asInt(r['user_id']),
              title: r['title']! as String,
              body: r['body']! as String,
              createdAtMs: _asInt(r['created_at_ms']),
              read: _asInt(r['read']) == 1,
              eventId: r['event_id'] == null ? null : _asInt(r['event_id']),
            );
          },
        )
        .toList();
  }

  Future<void> markNotificationRead(int notificationId, int userId) async {
    await _c
        .from(_notifications)
        .update(<String, dynamic>{'read': 1})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<int> countUnreadNotifications(int userId) async {
    final res = await _c.from(_notifications).select('id').eq('user_id', userId).eq('read', 0);
    return (res as List<dynamic>).length;
  }

  Future<List<AppUser>> listStudentsRoster() async {
    final users = await listUsers();
    final students = users.where((u) => u.roles.contains(UserRole.student)).toList();
    int cmp(AppUser a, AppUser b) {
      final ga = a.groupName ?? '';
      final gb = b.groupName ?? '';
      final c = ga.toLowerCase().compareTo(gb.toLowerCase());
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    students.sort(cmp);
    return students;
  }

  SocialHelpRequest _socialRequestFromRow(Map<String, dynamic> r) {
    final created = r['created_at_ms'];
    final updated = r['updated_at_ms'];
    return SocialHelpRequest(
      id: _asInt(r['id']),
      authorId: _asInt(r['author_id']),
      authorName: r['author_name']! as String,
      title: r['title']! as String,
      body: r['body']! as String,
      status: SocialRequestStatus.fromStored(r['status'] as String?),
      staffReply: r['staff_reply'] as String?,
      createdAtMs: created is int ? created : (created is num ? created.toInt() : 0),
      updatedAtMs: updated is int ? updated : (updated is num ? updated.toInt() : 0),
    );
  }

  Future<List<SocialHelpRequest>> listSocialRequests({
    required int viewerId,
    required UserRole viewerRole,
  }) async {
    final staff = viewerRole == UserRole.socialPedagogue || viewerRole == UserRole.deputyDirector;
    final dynamic list = staff
        ? await _c.from(_socialRequests).select().order('created_at_ms', ascending: false)
        : await _c
            .from(_socialRequests)
            .select()
            .eq('author_id', viewerId)
            .order('created_at_ms', ascending: false);
    return (list as List<dynamic>)
        .map((raw) => _socialRequestFromRow(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<String?> createSocialRequest({
    required int authorId,
    required String authorName,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _c.from(_socialRequests).insert(<String, dynamic>{
        'author_id': authorId,
        'author_name': authorName,
        'title': title,
        'body': body,
        'status': SocialRequestStatus.pending.name,
        'staff_reply': null,
        'created_at_ms': now,
        'updated_at_ms': now,
      });
    } on PostgrestException catch (e) {
      return 'Не удалось создать заявку: ${e.message}';
    } catch (e) {
      return 'Не удалось создать заявку: $e';
    }
    return null;
  }

  Future<String?> updateSocialRequestByStaff({
    required int requestId,
    required SocialRequestStatus newStatus,
    String? staffReply,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _c.from(_socialRequests).update(<String, dynamic>{
        'status': newStatus.name,
        'staff_reply': (staffReply == null || staffReply.trim().isEmpty) ? null : staffReply.trim(),
        'updated_at_ms': now,
      }).eq('id', requestId);
    } on PostgrestException catch (e) {
      return 'Ошибка: ${e.message}';
    }
    return null;
  }

  /// Проверка доступности таблиц после ввода ключей.
  Future<String?> selfTest() async {
    try {
      await _c.from(_users).select('id').limit(1);
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
