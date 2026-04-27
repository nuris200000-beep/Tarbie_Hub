import 'dart:io';

import 'package:flutter/material.dart';

String userAvatarInitial(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return t[0].toUpperCase();
}

/// Аватар из локального файла; при ошибке или отсутствии файла — инициалы.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.radius = 24,
    this.fontSize,
  });

  final String name;
  final String? imagePath;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letterSize = fontSize ?? (radius * 0.55).clamp(12.0, 40.0);
    final path = imagePath?.trim();
    if (path != null && path.isNotEmpty) {
      final isNetwork = path.startsWith('http://') || path.startsWith('https://');
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        child: ClipOval(
          child: isNetwork
              ? Image.network(
                  path,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        userAvatarInitial(name),
                        style: TextStyle(fontSize: letterSize, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                )
              : Image.file(
                  File(path),
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        userAvatarInitial(name),
                        style: TextStyle(fontSize: letterSize, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Text(
        userAvatarInitial(name),
        style: TextStyle(fontSize: letterSize, fontWeight: FontWeight.w600),
      ),
    );
  }
}
