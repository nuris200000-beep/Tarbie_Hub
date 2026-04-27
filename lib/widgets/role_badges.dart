import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// Студент — белый, персонал (куратор/психолог/соцпед) — зелёный, замдиректор — красный.
/// Отдельный бейдж «Администратор» — красный (права is_admin).
class RoleBadgeStyle {
  const RoleBadgeStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static RoleBadgeStyle forRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const RoleBadgeStyle(
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF424242),
          border: Color(0xFFBDBDBD),
        );
      case UserRole.deputyDirector:
        return const RoleBadgeStyle(
          background: Color(0xFFFFEBEE),
          foreground: Color(0xFFB71C1C),
          border: Color(0xFFE57373),
        );
      case UserRole.curator:
      case UserRole.psychologist:
      case UserRole.socialPedagogue:
        return const RoleBadgeStyle(
          background: Color(0xFFE8F5E9),
          foreground: Color(0xFF1B5E20),
          border: Color(0xFF81C784),
        );
    }
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final s = RoleBadgeStyle.forRole(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s.border),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: s.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AdminChip extends StatelessWidget {
  const AdminChip({super.key});

  @override
  Widget build(BuildContext context) {
    const s = RoleBadgeStyle(
      background: Color(0xFFFFEBEE),
      foreground: Color(0xFFB71C1C),
      border: Color(0xFFE57373),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s.border),
      ),
      child: Text(
        'Администратор',
        style: TextStyle(
          color: s.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RoleChipsRow extends StatelessWidget {
  const RoleChipsRow({super.key, required this.roles, required this.isAdmin});

  final List<UserRole> roles;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...roles.map((r) => RoleChip(role: r)),
        if (isAdmin) const AdminChip(),
      ],
    );
  }
}
