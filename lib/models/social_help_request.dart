/// Заявка на социальную помощь (общая для облака и SQLite).
enum SocialRequestStatus {
  pending('Новая'),
  inProgress('В работе'),
  resolved('Закрыта');

  const SocialRequestStatus(this.labelRu);
  final String labelRu;

  static SocialRequestStatus fromStored(String? raw) {
    if (raw == null || raw.isEmpty) return SocialRequestStatus.pending;
    for (final v in SocialRequestStatus.values) {
      if (v.name == raw) return v;
    }
    return SocialRequestStatus.pending;
  }
}

class SocialHelpRequest {
  const SocialHelpRequest({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.status,
    this.staffReply,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final int id;
  final int authorId;
  final String authorName;
  final String title;
  final String body;
  final SocialRequestStatus status;
  final String? staffReply;
  final int createdAtMs;
  final int updatedAtMs;
}
