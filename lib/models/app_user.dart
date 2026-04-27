import 'profile_status.dart';

enum UserRole {
  deputyDirector('Замдиректора'),
  psychologist('Психолог'),
  socialPedagogue('Соцпедагог'),
  curator('Куратор'),
  student('Студент');

  const UserRole(this.label);
  final String label;

  /// Мероприятие: от куратора и выше, студенты не создают.
  bool get canCreateEvents => this != UserRole.student;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.login,
    required this.name,
    required this.roles,
    this.isAdmin = false,
    this.avatarPath,
    this.status = ProfileStatus.online,
    this.lastSeenMs = 0,
    this.email,
    this.groupName,
  });

  final int id;
  final String login;
  final String name;
  final List<UserRole> roles;
  final bool isAdmin;
  final String? avatarPath;
  final ProfileStatus status;
  final int lastSeenMs;
  /// После регистрации; может быть null у старых записей.
  final String? email;
  /// Название учебной группы (из справочника на момент регистрации).
  final String? groupName;

  AppUser copyWith({
    String? name,
    List<UserRole>? roles,
    bool? isAdmin,
    String? avatarPath,
    ProfileStatus? status,
    int? lastSeenMs,
    String? email,
    String? groupName,
    bool clearAvatar = false,
  }) {
    return AppUser(
      id: id,
      login: login,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      isAdmin: isAdmin ?? this.isAdmin,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      status: status ?? this.status,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      email: email ?? this.email,
      groupName: groupName ?? this.groupName,
    );
  }

  static List<UserRole> rolesFromStored(String stored) {
    if (stored.trim().isEmpty) return <UserRole>[UserRole.student];
    final out = <UserRole>[];
    for (final part in stored.split(',')) {
      final name = part.trim();
      if (name.isEmpty) continue;
      try {
        out.add(UserRole.values.firstWhere((e) => e.name == name));
      } catch (_) {}
    }
    return out.isEmpty ? <UserRole>[UserRole.student] : out;
  }

  static String rolesToStored(List<UserRole> roles) =>
      roles.map((r) => r.name).join(',');
}
