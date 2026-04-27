class HubNotification {
  const HubNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAtMs,
    required this.read,
    this.eventId,
  });

  final int id;
  final int userId;
  final String title;
  final String body;
  final int createdAtMs;
  final bool read;
  final int? eventId;
}
