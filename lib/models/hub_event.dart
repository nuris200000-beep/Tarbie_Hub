class HubEvent {
  const HubEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.valueTag,
    required this.groupName,
    required this.authorId,
    required this.authorName,
    required this.createdAtMs,
  });

  final int id;
  final String title;
  final String description;
  final String valueTag;
  final String groupName;
  final int authorId;
  final String authorName;
  final int createdAtMs;
}
