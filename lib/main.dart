import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/tarbie_cloud_config.dart';
import 'data/app_database.dart';
import 'models/app_user.dart';
import 'platform/init_sqflite_export.dart';
import 'ui/admin_page.dart';
import 'ui/auth_pages.dart';
import 'ui/event_create_page.dart';
import 'ui/feed_page.dart';
import 'ui/notifications_page.dart';
import 'ui/profile_page.dart';
import 'ui/psychologist_module_page.dart';
import 'ui/social_requests_page.dart';
import 'widgets/role_badges.dart';
import 'widgets/user_avatar.dart';

const Color _kBrandNavy = Color(0xFF1A2E4A);
const Color _kBrandTurquoise = Color(0xFF4FD1C5);
const Color _kBrandCoral = Color(0xFFE57373);
const Color _kSurfaceLight = Color(0xFFFAFBFC);
const Color _kCardLight = Color(0xFFFFFFFF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (TarbieCloudConfig.isCloudEnabled) {
    await Supabase.initialize(
      url: TarbieCloudConfig.supabaseUrl,
      anonKey: TarbieCloudConfig.supabaseAnonKey,
    );
  }
  await initSqfliteForDesktop();
  await AppDatabase.instance.init();
  runApp(const TarbieHubApp());
}

enum AppSection {
  newsFeed('Лента', Icons.dynamic_feed_outlined),
  eventCreate('Создать мероприятие', Icons.add_circle_outline),
  psychologist('Модуль психолога', Icons.psychology_outlined),
  social('Соц. заявки', Icons.volunteer_activism_outlined),
  notifications('Уведомления', Icons.notifications_none),
  profile('Профиль', Icons.person_outline),
  adminPanel('Админ-панель', Icons.admin_panel_settings_outlined);

  const AppSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

class TarbieHubApp extends StatefulWidget {
  const TarbieHubApp({super.key});

  @override
  State<TarbieHubApp> createState() => _TarbieHubAppState();
}

class _TarbieHubAppState extends State<TarbieHubApp> with WidgetsBindingObserver {
  AppUser? _currentUser;
  UserRole? _activeRole;
  Timer? _presencePulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _presencePulse?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final u = _currentUser;
    if (u != null &&
        (state == AppLifecycleState.paused || state == AppLifecycleState.detached)) {
      AppDatabase.instance.touchPresence(u.id);
    }
  }

  void _startPresencePulse() {
    _presencePulse?.cancel();
    _presencePulse = Timer.periodic(const Duration(seconds: 25), (_) {
      final u = _currentUser;
      if (u != null) {
        AppDatabase.instance.touchPresence(u.id);
      }
    });
  }

  void _stopPresencePulse() {
    _presencePulse?.cancel();
    _presencePulse = null;
  }

  void _onLogin(AppUser user) {
    setState(() {
      _currentUser = user;
      _activeRole = user.roles.length == 1 ? user.roles.first : null;
    });
    _startPresencePulse();
  }

  void _onRoleSelect(UserRole role) {
    setState(() {
      _activeRole = role;
    });
  }

  void _openRoleSelection() {
    setState(() {
      _activeRole = null;
    });
  }

  void _logout() {
    final u = _currentUser;
    _stopPresencePulse();
    if (u != null) {
      AppDatabase.instance.touchPresence(u.id);
    }
    setState(() {
      _currentUser = null;
      _activeRole = null;
    });
  }

  void _onUserProfileUpdated(AppUser u) {
    setState(() => _currentUser = u);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'College Tarbie Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kBrandNavy,
          primary: _kBrandNavy,
          secondary: _kBrandTurquoise,
          tertiary: const Color(0xFFFBBF24),
          error: _kBrandCoral,
          surface: _kSurfaceLight,
        ),
        scaffoldBackgroundColor: _kSurfaceLight,
        cardColor: _kCardLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _kBrandNavy,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          margin: EdgeInsets.zero,
          shadowColor: _kBrandNavy.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.24)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.24)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: _kBrandTurquoise, width: 1.5),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _kBrandTurquoise.withValues(alpha: 0.10),
          selectedColor: _kBrandTurquoise.withValues(alpha: 0.22),
          side: BorderSide(color: _kBrandTurquoise.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          labelStyle: const TextStyle(color: _kBrandNavy, fontWeight: FontWeight.w600),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _kBrandNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(0, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _kBrandNavy,
            side: BorderSide(color: _kBrandNavy.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(0, 44),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.97),
          indicatorColor: _kBrandTurquoise.withValues(alpha: 0.22),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? _kBrandNavy : Colors.grey.shade600,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected) ? _kBrandNavy : Colors.grey.shade600,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: _currentUser == null
          ? LoginPage(onLoggedIn: _onLogin)
          : _activeRole == null
              ? RoleSelectionPage(
                  user: _currentUser!,
                  onSelectRole: _onRoleSelect,
                  onLogout: _logout,
                )
              : AppShell(
                  user: _currentUser!,
                  role: _activeRole!,
                  onChangeRole: _currentUser!.roles.length > 1
                      ? _openRoleSelection
                      : null,
                  onLogout: _logout,
                  onUserUpdated: _onUserProfileUpdated,
                ),
    );
  }
}

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({
    super.key,
    required this.user,
    required this.onSelectRole,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<UserRole> onSelectRole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор роли'),
        actions: [
          TextButton(onPressed: onLogout, child: const Text('Выйти')),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text('У вас несколько ролей. Выберите рабочий контур:'),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: user.roles.map((role) {
                    final s = RoleBadgeStyle.forRole(role);
                    return ActionChip(
                      label: Text(role.label),
                      backgroundColor: s.background,
                      side: BorderSide(color: s.border),
                      labelStyle: TextStyle(color: s.foreground, fontWeight: FontWeight.w600),
                      onPressed: () => onSelectRole(role),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.role,
    required this.onLogout,
    required this.onUserUpdated,
    this.onChangeRole,
  });

  final AppUser user;
  final UserRole role;
  final VoidCallback onLogout;
  final ValueChanged<AppUser> onUserUpdated;
  final VoidCallback? onChangeRole;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppSection _section;
  int _feedReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _section = _allowedSections(widget.role).first;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _section = _allowedSections(widget.role).first;
    }
  }

  static List<AppSection> _allowedSections(UserRole role) {
    switch (role) {
      case UserRole.deputyDirector:
        return const [
          AppSection.newsFeed,
          AppSection.eventCreate,
          AppSection.psychologist,
          AppSection.social,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.curator:
        return const [
          AppSection.newsFeed,
          AppSection.eventCreate,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.psychologist:
        return const [
          AppSection.newsFeed,
          AppSection.eventCreate,
          AppSection.psychologist,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.socialPedagogue:
        return const [
          AppSection.newsFeed,
          AppSection.eventCreate,
          AppSection.social,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.student:
        return const [
          AppSection.newsFeed,
          AppSection.social,
          AppSection.notifications,
          AppSection.profile,
        ];
    }
  }

  List<AppSection> _visibleSections() {
    final base = _allowedSections(widget.role);
    if (widget.user.isAdmin) {
      return <AppSection>[...base, AppSection.adminPanel];
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections();
    final activeSection =
        sections.contains(_section) ? _section : sections.first;
    if (activeSection != _section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _section = activeSection);
      });
    }
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1280;
    final isTablet = width >= 768 && width < 1280;
    final content = _SectionContent(
      section: activeSection,
      user: widget.user,
      role: widget.role,
      feedReloadToken: _feedReloadToken,
      onUserUpdated: widget.onUserUpdated,
      onPublishedGoFeed: () => setState(() {
        _feedReloadToken++;
        _section = AppSection.newsFeed;
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tarbie Hub',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _kBrandNavy,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '${widget.role.label} • ${activeSection.title}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          if (widget.onChangeRole != null)
            TextButton(
              onPressed: widget.onChangeRole,
              child: const Text('Сменить роль'),
            ),
          TextButton(onPressed: widget.onLogout, child: const Text('Выйти')),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: _buildNavigationList(sections, activeSection)),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kBrandTurquoise.withValues(alpha: 0.10),
              _kSurfaceLight,
              _kSurfaceLight,
            ],
          ),
        ),
        child: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              NavigationRail(
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(
                        name: widget.user.name,
                        imagePath: widget.user.avatarPath,
                        radius: 26,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Text(
                          widget.user.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user.status.labelRu,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                selectedIndex: sections.indexOf(activeSection),
                onDestinationSelected: (index) =>
                    setState(() => _section = sections[index]),
                labelType: NavigationRailLabelType.all,
                destinations: sections
                    .map((s) =>
                        NavigationRailDestination(icon: Icon(s.icon), label: Text(s.title)))
                    .toList(),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320, minWidth: 320),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 24 : 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: content),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _QuickPanel(
                                      role: widget.role,
                                      user: widget.user,
                                    ),
                                  ),
                                ],
                              )
                            : isTablet
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: content),
                                      const SizedBox(width: 12),
                                      Expanded(child: _QuickPanel(role: widget.role, user: widget.user)),
                                    ],
                                  )
                                : content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      )),
      bottomNavigationBar: width <= 767
          ? () {
              final navSections = sections.take(4).toList();
              var navIndex = navSections.indexOf(activeSection);
              if (navIndex < 0) navIndex = 0;
              return NavigationBar(
                selectedIndex: navIndex,
                destinations: navSections
                    .map((s) => NavigationDestination(icon: Icon(s.icon), label: s.title))
                    .toList(),
                onDestinationSelected: (index) =>
                    setState(() => _section = navSections[index]),
              );
            }()
          : null,
    );
  }

  Widget _buildNavigationList(List<AppSection> sections, AppSection activeSection) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      children: [
        DrawerHeader(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
          child: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(
                  name: widget.user.name,
                  imagePath: widget.user.avatarPath,
                  radius: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.user.name,
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.status.labelRu,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${widget.user.login}',
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ...sections.map(
          (s) => ListTile(
            selected: activeSection == s,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(s.icon),
            title: Text(s.title),
            onTap: () {
              setState(() => _section = s);
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.section,
    required this.user,
    required this.role,
    required this.feedReloadToken,
    required this.onUserUpdated,
    required this.onPublishedGoFeed,
  });

  final AppSection section;
  final AppUser user;
  final UserRole role;
  final int feedReloadToken;
  final ValueChanged<AppUser> onUserUpdated;
  final VoidCallback onPublishedGoFeed;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AppSection.newsFeed:
        return FeedPage(
          key: ValueKey<int>(feedReloadToken),
          currentUser: user,
          activeRole: role,
        );
      case AppSection.eventCreate:
        return EventCreatePage(
          author: user,
          activeRole: role,
          onPublished: onPublishedGoFeed,
        );
      case AppSection.psychologist:
        return const PsychologistModulePage();
      case AppSection.social:
        return SocialRequestsPage(user: user, role: role);
      case AppSection.notifications:
        return NotificationsPage(user: user);
      case AppSection.profile:
        return ProfilePage(
          user: user,
          role: role,
          onUserUpdated: onUserUpdated,
        );
      case AppSection.adminPanel:
        return AdminPanelPage(currentUser: user);
    }
  }
}

class _QuickPanel extends StatelessWidget {
  const _QuickPanel({required this.role, required this.user});

  final UserRole role;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: _kBrandTurquoise,
                  child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'Сейчас',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _kBrandNavy,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Роль в контуре: ${role.label}'),
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: AppDatabase.instance.countUnreadNotifications(user.id),
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return Text(
                  n > 0 ? 'Непрочитанных уведомлений: $n' : 'Нет непрочитанных уведомлений',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              },
            ),
            if (user.isAdmin) ...[
              const SizedBox(height: 12),
              Text(
                'Администратор: пункт «Админ-панель» в меню.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
