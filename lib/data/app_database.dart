import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../auth/password_policy.dart';
import '../config/tarbie_cloud_config.dart';
import '../models/app_user.dart';
import '../models/student_group.dart';
import 'auth_crypto.dart';
import 'remote_supabase_store.dart';
import '../models/hub_event.dart';
import '../models/hub_feed_entry.dart';
import '../models/hub_notification.dart';
import '../models/profile_status.dart';
import '../models/social_help_request.dart';

/// Данные: общий Supabase (если задан в [TarbieCloudConfig]) или локальная SQLite.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  bool _inMemory = false;
  bool _useRemote = false;
  String? _remoteSelfTestError;

  /// `true` — данные в Supabase, общие для всех устройств с тем же проектом.
  bool get usesSharedCloud => _useRemote;

  /// Если в конфиге включено облако, но при старте не удалось подключиться — не `null`.
  /// Тогда используется только локальная SQLite на этом устройстве (другие не увидят ваших пользователей).
  String? get sharedCloudUnavailableReason {
    if (_inMemory || !TarbieCloudConfig.isCloudEnabled) return null;
    if (_useRemote) return null;
    return _remoteSelfTestError ?? 'Не удалось подключиться к Supabase';
  }

  Future<Database> get database async {
    if (_useRemote) {
      throw StateError('В режиме облака SQLite не используется');
    }
    final d = _db;
    if (d != null) return d;
    throw StateError('Вызовите AppDatabase.instance.init() перед использованием');
  }

  Future<void> init({bool inMemory = false}) async {
    await _db?.close();
    _db = null;
    _useRemote = false;
    _remoteSelfTestError = null;
    _inMemory = inMemory;
    if (inMemory) {
      _db = await _open();
      return;
    }
    if (TarbieCloudConfig.isCloudEnabled) {
      try {
        final err = await RemoteSupabaseStore.instance.selfTest();
        _useRemote = err == null;
        _remoteSelfTestError = err;
      } catch (e) {
        _useRemote = false;
        _remoteSelfTestError = '$e';
      }
    }
    if (!_useRemote) {
      _db = await _open();
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> resetForTest() async {
    await close();
    await init(inMemory: true);
  }

  static const int _version = 4;

  Future<Database> _open() async {
    final String path;
    if (_inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, 'tarbie_hub.db');
    }

    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _createSchemaV3(db);
        await _seedAdmin(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
      },
    );
  }

  Future<void> _upgradeToV4(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS social_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id INTEGER NOT NULL,
  author_name TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  staff_reply TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
  }

  Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS student_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
''');
    try {
      await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
    } on DatabaseException catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN group_id INTEGER');
    } on DatabaseException catch (_) {}
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower
ON users (lower(email))
WHERE email IS NOT NULL AND length(trim(email)) > 0
''');
    await db.update(
      'users',
      <String, Object?>{'email': 'admin@tarbie.local'},
      where: 'login = ?',
      whereArgs: <Object>['admin'],
    );
  }

  Future<void> _createSchemaV3(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE student_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
''');
    await db.execute('''
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  login TEXT NOT NULL UNIQUE COLLATE NOCASE,
  display_name TEXT NOT NULL,
  email TEXT,
  group_id INTEGER,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  roles TEXT NOT NULL,
  is_admin INTEGER NOT NULL DEFAULT 0,
  reset_code TEXT,
  reset_expires_ms INTEGER,
  avatar_path TEXT,
  status TEXT NOT NULL DEFAULT 'online',
  last_seen_ms INTEGER NOT NULL DEFAULT 0
);
''');
    await db.execute('''
CREATE UNIQUE INDEX idx_users_email_lower
ON users (lower(email))
WHERE email IS NOT NULL AND length(trim(email)) > 0
''');
    await db.execute('''
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  value_tag TEXT NOT NULL,
  group_name TEXT NOT NULL,
  author_id INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  event_id INTEGER
);
''');
    await db.execute('''
CREATE TABLE social_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id INTEGER NOT NULL,
  author_name TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  staff_reply TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute('ALTER TABLE users ADD COLUMN avatar_path TEXT');
    await db.execute(
        "ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'online'");
    await db.execute(
        'ALTER TABLE users ADD COLUMN last_seen_ms INTEGER NOT NULL DEFAULT 0');
    await db.execute('''
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  value_tag TEXT NOT NULL,
  group_name TEXT NOT NULL,
  author_id INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  event_id INTEGER
);
''');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate('UPDATE users SET last_seen_ms = ? WHERE last_seen_ms = 0', <Object>[now]);
  }

  Future<void> _seedAdmin(Database db) async {
    const login = 'admin';
    const password = 'Admin123';
    const displayName = 'Администратор';
    final salt = AuthCrypto.randomSalt();
    final hash = AuthCrypto.hashPassword(password, salt);
    final roles = AppUser.rolesToStored(<UserRole>[
      UserRole.deputyDirector,
      UserRole.curator,
    ]);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('users', <String, Object?>{
      'login': login,
      'display_name': displayName,
      'email': 'admin@tarbie.local',
      'password_hash': hash,
      'salt': salt,
      'roles': roles,
      'is_admin': 1,
      'status': ProfileStatus.online.name,
      'last_seen_ms': now,
    });
  }

  String? _validateEmailFormat(String email) {
    final t = email.trim();
    if (t.length < 5) return 'Введите корректный email';
    if (!t.contains('@') || !t.contains('.')) return 'Введите корректный email';
    return null;
  }

  Future<String?> register({
    required String login,
    required String displayName,
    required String email,
    required int groupId,
    required String password,
  }) async {
    final emailErr = _validateEmailFormat(email);
    if (emailErr != null) return emailErr;
    final pwdErr = PasswordPolicy.validate(password);
    if (pwdErr != null) return pwdErr;

    if (_useRemote) {
      return RemoteSupabaseStore.instance.register(
        login: login,
        displayName: displayName,
        email: email.trim().toLowerCase(),
        groupId: groupId,
        password: password,
      );
    }
    final db = await database;
    final trimmedLogin = login.trim().toLowerCase();
    final emailLower = email.trim().toLowerCase();
    if (trimmedLogin.length < 3) return 'Логин не короче 3 символов';
    if (displayName.trim().length < 2) return 'Введите имя';

    final g = await db.query('student_groups', where: 'id = ?', whereArgs: <Object>[groupId], limit: 1);
    if (g.isEmpty) return 'Выберите группу из списка';

    final salt = AuthCrypto.randomSalt();
    final hash = AuthCrypto.hashPassword(password, salt);
    final roles = AppUser.rolesToStored(<UserRole>[UserRole.student]);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert('users', <String, Object?>{
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
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE constraint') || msg.contains('unique')) {
        if (msg.toLowerCase().contains('email') || msg.contains('idx_users_email')) {
          return 'Этот email уже зарегистрирован';
        }
        return 'Такой логин уже занят';
      }
      return 'Ошибка регистрации';
    }
    return null;
  }

  Future<AppUser?> login(String login, String password) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.login(login, password);
    }
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(login) = LOWER(?)',
      whereArgs: <Object>[login.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final salt = row['salt']! as String;
    final hash = AuthCrypto.hashPassword(password, salt);
    if (hash != row['password_hash']) return null;
    final user = _rowToUser(row);
    await touchPresence(user.id);
    return getUserById(user.id);
  }

  AppUser _rowToUser(Map<String, Object?> row) {
    final lastSeen = row['last_seen_ms'];
    return AppUser(
      id: row['id']! as int,
      login: row['login']! as String,
      name: row['display_name']! as String,
      roles: AppUser.rolesFromStored(row['roles']! as String),
      isAdmin: (row['is_admin'] as int) == 1,
      avatarPath: row['avatar_path'] as String?,
      status: ProfileStatus.fromStored(row['status'] as String?),
      lastSeenMs: lastSeen is int
          ? lastSeen
          : (lastSeen is num ? lastSeen.toInt() : 0),
      email: row['email'] as String?,
      groupName: row['group_name'] as String?,
    );
  }

  Future<AppUser?> getUserById(int id) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.getUserById(id);
    }
    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT u.*, g.name AS group_name
FROM users u
LEFT JOIN student_groups g ON g.id = u.group_id
WHERE u.id = ?
''',
      <Object>[id],
    );
    if (rows.isEmpty) return null;
    return _rowToUser(rows.first);
  }

  Future<void> touchPresence(int userId) async {
    if (_useRemote) {
      await RemoteSupabaseStore.instance.touchPresence(userId);
      return;
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'users',
      <String, Object?>{'last_seen_ms': now},
      where: 'id = ?',
      whereArgs: <Object>[userId],
    );
  }

  Future<String?> updateProfile({
    required int userId,
    String? displayName,
    String? avatarPath,
    ProfileStatus? status,
  }) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.updateProfile(
        userId: userId,
        displayName: displayName,
        avatarPath: avatarPath,
        status: status,
      );
    }
    final db = await database;
    final map = <String, Object?>{};
    if (displayName != null) map['display_name'] = displayName.trim();
    if (avatarPath != null) map['avatar_path'] = avatarPath;
    if (status != null) map['status'] = status.name;
    if (map.isEmpty) return null;
    await db.update('users', map, where: 'id = ?', whereArgs: <Object>[userId]);
    return null;
  }

  Future<String?> clearAvatar(int userId) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.clearAvatar(userId);
    }
    final u = await getUserById(userId);
    final path = u?.avatarPath;
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final db = await database;
    await db.update(
      'users',
      <String, Object?>{'avatar_path': null},
      where: 'id = ?',
      whereArgs: <Object>[userId],
    );
    return null;
  }

  /// Локально: путь к файлу. В облаке: публичный URL в Storage.
  Future<String?> saveAvatarFromFile(int userId, String pickedFilePath) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.saveAvatarFromFile(userId, pickedFilePath);
    }
    final dir = await getApplicationDocumentsDirectory();
    final avDir = Directory(p.join(dir.path, 'avatars'));
    if (!await avDir.exists()) {
      await avDir.create(recursive: true);
    }
    final ext = p.extension(pickedFilePath).toLowerCase();
    final safeExt = (ext.isEmpty || ext.length > 5) ? '.jpg' : ext;
    final destPath = p.join(avDir.path, 'user_$userId$safeExt');
    await File(pickedFilePath).copy(destPath);
    return destPath;
  }

  /// Вводится логин; код всегда уходит на email, который сохранён у этого пользователя.
  Future<String?> requestPasswordResetForLogin(String login) async {
    final key = login.trim().toLowerCase();
    if (key.length < 3) return 'Введите логин';
    if (_useRemote) {
      return RemoteSupabaseStore.instance.requestPasswordResetForLogin(key);
    }
    return 'Отправка кода на почту работает только в облачном режиме (Supabase + Edge Function send-reset-code).';
  }

  Future<String?> completePasswordReset({
    required String login,
    required String code,
    required String newPassword,
  }) async {
    final pwdErr = PasswordPolicy.validate(newPassword);
    if (pwdErr != null) return pwdErr;
    if (_useRemote) {
      return RemoteSupabaseStore.instance.completePasswordReset(
        login: login.trim().toLowerCase(),
        code: code,
        newPassword: newPassword,
      );
    }
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(login) = LOWER(?)',
      whereArgs: <Object>[login.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return 'Пользователь с таким логином не найден';
    final row = rows.first;
    final stored = row['reset_code'] as String?;
    final exp = row['reset_expires_ms'] as int?;
    if (stored == null || exp == null) return 'Сначала запросите код сброса';
    if (DateTime.now().millisecondsSinceEpoch > exp) return 'Код истёк, запросите новый';
    if (stored != code.trim()) return 'Неверный код';

    final salt = AuthCrypto.randomSalt();
    final hash = AuthCrypto.hashPassword(newPassword, salt);
    await db.update(
      'users',
      <String, Object?>{
        'password_hash': hash,
        'salt': salt,
        'reset_code': null,
        'reset_expires_ms': null,
      },
      where: 'id = ?',
      whereArgs: <Object>[row['id'] as int],
    );
    return null;
  }

  Future<List<StudentGroup>> listStudentGroups() async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listStudentGroups();
    }
    final db = await database;
    final rows = await db.query('student_groups', orderBy: 'name COLLATE NOCASE ASC');
    return rows
        .map(
          (r) => StudentGroup(
            id: r['id']! as int,
            name: r['name']! as String,
          ),
        )
        .toList();
  }

  Future<String?> addStudentGroup(String name) async {
    final t = name.trim();
    if (t.length < 2) return 'Название группы не короче 2 символов';
    if (_useRemote) {
      return RemoteSupabaseStore.instance.addStudentGroup(t);
    }
    final db = await database;
    try {
      await db.insert('student_groups', <String, Object?>{'name': t});
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('UNIQUE') || msg.contains('unique')) {
        return 'Такая группа уже есть';
      }
      return 'Не удалось добавить группу';
    }
    return null;
  }

  Future<String?> deleteStudentGroup(int groupId) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.deleteStudentGroup(groupId);
    }
    final db = await database;
    await db.update('users', <String, Object?>{'group_id': null}, where: 'group_id = ?', whereArgs: <Object>[groupId]);
    final n = await db.delete('student_groups', where: 'id = ?', whereArgs: <Object>[groupId]);
    if (n == 0) return 'Группа не найдена';
    return null;
  }

  Future<List<AppUser>> listUsers() async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listUsers();
    }
    final db = await database;
    final rows = await db.rawQuery('''
SELECT u.*, g.name AS group_name
FROM users u
LEFT JOIN student_groups g ON g.id = u.group_id
ORDER BY u.login COLLATE NOCASE ASC
''');
    return rows.map(_rowToUser).toList();
  }

  Future<String?> deleteUser({required int userId, required int actorId}) async {
    if (userId == actorId) return 'Нельзя удалить свою учётную запись';
    if (_useRemote) {
      return RemoteSupabaseStore.instance.deleteUser(userId: userId, actorId: actorId);
    }
    final db = await database;
    final n = await db.delete('users', where: 'id = ?', whereArgs: <Object>[userId]);
    if (n == 0) return 'Пользователь не найден';
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
    if (_useRemote) {
      return RemoteSupabaseStore.instance.updateUserRolesAndAdmin(
        targetUserId: targetUserId,
        roles: sorted,
        isAdmin: isAdmin,
      );
    }
    final db = await database;
    await db.update(
      'users',
      <String, Object?>{
        'roles': AppUser.rolesToStored(sorted),
        'is_admin': isAdmin ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: <Object>[targetUserId],
    );
    return null;
  }

  Future<List<HubFeedEntry>> listFeedEntries() async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listFeedEntries();
    }
    final db = await database;
    final rows = await db.rawQuery('''
SELECT e.id, e.title, e.description, e.value_tag, e.group_name, e.author_id, e.created_at_ms,
       u.display_name AS author_name,
       u.avatar_path AS author_avatar_path,
       u.roles AS author_roles,
       u.is_admin AS author_is_admin,
       u.last_seen_ms AS author_last_seen,
       u.status AS author_status
FROM events e
JOIN users u ON u.id = e.author_id
ORDER BY e.created_at_ms DESC
''');
    return rows.map((r) {
      final lastSeen = r['author_last_seen'];
      return HubFeedEntry(
        event: HubEvent(
          id: r['id']! as int,
          title: r['title']! as String,
          description: r['description']! as String,
          valueTag: r['value_tag']! as String,
          groupName: r['group_name']! as String,
          authorId: r['author_id']! as int,
          authorName: r['author_name']! as String,
          createdAtMs: r['created_at_ms']! as int,
        ),
        authorRoles: AppUser.rolesFromStored(r['author_roles']! as String),
        authorIsAdmin: (r['author_is_admin'] as int) == 1,
        authorLastSeenMs: lastSeen is int ? lastSeen : 0,
        authorStatus: ProfileStatus.fromStored(r['author_status'] as String?),
        authorAvatarPath: r['author_avatar_path'] as String?,
      );
    }).toList();
  }

  Future<int> createEventAndNotifyAll({
    required int authorId,
    required String title,
    required String description,
    required String valueTag,
    required String groupName,
  }) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.createEventAndNotifyAll(
        authorId: authorId,
        title: title,
        description: description,
        valueTag: valueTag,
        groupName: groupName,
      );
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final eventId = await db.insert('events', <String, Object?>{
      'title': title.trim(),
      'description': description.trim(),
      'value_tag': valueTag.trim(),
      'group_name': groupName.trim(),
      'author_id': authorId,
      'created_at_ms': now,
    });
    final users = await db.query('users', columns: <String>['id']);
    final batch = db.batch();
    for (final row in users) {
      final uid = row['id']! as int;
      batch.insert('notifications', <String, Object?>{
        'user_id': uid,
        'title': 'Новое мероприятие',
        'body': title.trim(),
        'created_at_ms': now,
        'read': 0,
        'event_id': eventId,
      });
    }
    await batch.commit(noResult: true);
    return eventId;
  }

  Future<String?> deleteEvent({
    required int eventId,
    required int actorId,
  }) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.deleteEvent(
        eventId: eventId,
        actorId: actorId,
      );
    }
    final db = await database;
    final actor = await getUserById(actorId);
    if (actor == null) return 'Пользователь не найден';

    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: <Object>[eventId],
      limit: 1,
    );
    if (rows.isEmpty) return 'Мероприятие не найдено';

    final event = rows.first;
    final authorId = event['author_id'] as int;
    final canDelete = actor.isAdmin ||
        actor.roles.contains(UserRole.deputyDirector) ||
        authorId == actorId;
    if (!canDelete) return 'Недостаточно прав для удаления мероприятия';

    await db.transaction((tx) async {
      await tx.delete('events', where: 'id = ?', whereArgs: <Object>[eventId]);
      await tx.delete(
        'notifications',
        where: 'event_id = ?',
        whereArgs: <Object>[eventId],
      );
    });
    return null;
  }

  Future<List<HubNotification>> listNotifications(int userId) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listNotifications(userId);
    }
    final db = await database;
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: <Object>[userId],
      orderBy: 'created_at_ms DESC',
    );
    return rows
        .map(
          (r) => HubNotification(
            id: r['id']! as int,
            userId: r['user_id']! as int,
            title: r['title']! as String,
            body: r['body']! as String,
            createdAtMs: r['created_at_ms']! as int,
            read: (r['read'] as int) == 1,
            eventId: r['event_id'] as int?,
          ),
        )
        .toList();
  }

  Future<void> markNotificationRead(int notificationId, int userId) async {
    if (_useRemote) {
      await RemoteSupabaseStore.instance.markNotificationRead(notificationId, userId);
      return;
    }
    final db = await database;
    await db.update(
      'notifications',
      <String, Object?>{'read': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object>[notificationId, userId],
    );
  }

  /// Студенты (роль student) для модуля психолога: группа, статус, активность.
  Future<List<AppUser>> listStudentsRoster() async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listStudentsRoster();
    }
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

  SocialHelpRequest _rowToSocialHelpRequest(Map<String, Object?> r) {
    final created = r['created_at_ms'];
    final updated = r['updated_at_ms'];
    return SocialHelpRequest(
      id: r['id']! as int,
      authorId: r['author_id']! as int,
      authorName: r['author_name']! as String,
      title: r['title']! as String,
      body: r['body']! as String,
      status: SocialRequestStatus.fromStored(r['status'] as String?),
      staffReply: r['staff_reply'] as String?,
      createdAtMs: created is int ? created : (created is num ? created.toInt() : 0),
      updatedAtMs: updated is int ? updated : (updated is num ? updated.toInt() : 0),
    );
  }

  /// Студент видит только свои заявки; соцпед и замдиректор — все.
  Future<List<SocialHelpRequest>> listSocialRequests({
    required int viewerId,
    required UserRole viewerRole,
  }) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.listSocialRequests(
        viewerId: viewerId,
        viewerRole: viewerRole,
      );
    }
    final db = await database;
    final staff = viewerRole == UserRole.socialPedagogue || viewerRole == UserRole.deputyDirector;
    final rows = staff
        ? await db.rawQuery('''
SELECT id, author_id, author_name, title, body, status, staff_reply, created_at_ms, updated_at_ms
FROM social_requests
ORDER BY created_at_ms DESC
''')
        : await db.rawQuery(
            '''
SELECT id, author_id, author_name, title, body, status, staff_reply, created_at_ms, updated_at_ms
FROM social_requests
WHERE author_id = ?
ORDER BY created_at_ms DESC
''',
            <Object>[viewerId],
          );
    return rows.map(_rowToSocialHelpRequest).toList();
  }

  Future<String?> createSocialRequest({
    required int authorId,
    required String title,
    required String body,
  }) async {
    final t = title.trim();
    final b = body.trim();
    if (t.length < 3) return 'Тема не короче 3 символов';
    if (b.length < 10) return 'Описание не короче 10 символов';
    final author = await getUserById(authorId);
    if (author == null) return 'Пользователь не найден';
    if (_useRemote) {
      return RemoteSupabaseStore.instance.createSocialRequest(
        authorId: authorId,
        authorName: author.name,
        title: t,
        body: b,
      );
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('social_requests', <String, Object?>{
      'author_id': authorId,
      'author_name': author.name,
      'title': t,
      'body': b,
      'status': SocialRequestStatus.pending.name,
      'staff_reply': null,
      'created_at_ms': now,
      'updated_at_ms': now,
    });
    return null;
  }

  Future<String?> updateSocialRequestByStaff({
    required int requestId,
    required UserRole staffRole,
    required SocialRequestStatus newStatus,
    String? staffReply,
  }) async {
    if (staffRole != UserRole.socialPedagogue && staffRole != UserRole.deputyDirector) {
      return 'Недостаточно прав';
    }
    if (_useRemote) {
      return RemoteSupabaseStore.instance.updateSocialRequestByStaff(
        requestId: requestId,
        newStatus: newStatus,
        staffReply: staffReply,
      );
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final n = await db.update(
      'social_requests',
      <String, Object?>{
        'status': newStatus.name,
        'staff_reply': staffReply?.trim().isEmpty == true ? null : staffReply?.trim(),
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: <Object>[requestId],
    );
    if (n == 0) return 'Заявка не найдена';
    return null;
  }

  Future<int> countUnreadNotifications(int userId) async {
    if (_useRemote) {
      return RemoteSupabaseStore.instance.countUnreadNotifications(userId);
    }
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE user_id = ? AND read = 0',
      <Object>[userId],
    );
    final n = r.first['c'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return 0;
  }
}
