import 'app_user.dart';
import 'hub_event.dart';
import 'profile_status.dart';

class HubFeedEntry {
  const HubFeedEntry({
    required this.event,
    required this.authorRoles,
    required this.authorIsAdmin,
    required this.authorLastSeenMs,
    required this.authorStatus,
    this.authorAvatarPath,
  });

  final HubEvent event;
  final List<UserRole> authorRoles;
  final bool authorIsAdmin;
  final int authorLastSeenMs;
  final ProfileStatus authorStatus;
  final String? authorAvatarPath;
}
