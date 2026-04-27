/// Текстовый статус в профиле (настроение / занятость).
enum ProfileStatus {
  online('В сети'),
  away('Отошёл(-ла)'),
  busy('Занят(-а)'),
  invisible('Вне сети');

  const ProfileStatus(this.labelRu);
  final String labelRu;

  static ProfileStatus fromStored(String? raw) {
    if (raw == null || raw.isEmpty) return ProfileStatus.online;
    for (final v in ProfileStatus.values) {
      if (v.name == raw) return v;
    }
    return ProfileStatus.online;
  }
}
