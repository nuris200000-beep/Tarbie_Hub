import 'package:flutter/material.dart';

void main() {
  runApp(const TarbieHubApp());
}

enum UserRole {
  deputyDirector('Замдиректора'),
  psychologist('Психолог'),
  socialPedagogue('Соцпедагог'),
  curator('Куратор'),
  student('Студент');

  const UserRole(this.label);
  final String label;
}

enum AppSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  events('Мероприятия', Icons.event_note_outlined),
  eventCreate('Создать мероприятие', Icons.add_circle_outline),
  eventDetails('Карточка мероприятия', Icons.assignment_outlined),
  psychologist('Модуль психолога', Icons.psychology_outlined),
  social('Соц. заявки', Icons.volunteer_activism_outlined),
  notifications('Уведомления', Icons.notifications_none),
  profile('Профиль', Icons.person_outline);

  const AppSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

class AppUser {
  const AppUser({
    required this.login,
    required this.name,
    required this.roles,
  });

  final String login;
  final String name;
  final List<UserRole> roles;
}

const List<AppUser> mockUsers = <AppUser>[
  AppUser(
    login: 'admin',
    name: 'Алия Куанышевна',
    roles: <UserRole>[UserRole.deputyDirector, UserRole.curator],
  ),
  AppUser(
    login: 'psy',
    name: 'Гульмира С.',
    roles: <UserRole>[UserRole.psychologist],
  ),
  AppUser(
    login: 'social',
    name: 'Руслан Ж.',
    roles: <UserRole>[UserRole.socialPedagogue],
  ),
  AppUser(
    login: 'student',
    name: 'Айбар Н.',
    roles: <UserRole>[UserRole.student],
  ),
];

class TarbieHubApp extends StatefulWidget {
  const TarbieHubApp({super.key});

  @override
  State<TarbieHubApp> createState() => _TarbieHubAppState();
}

class _TarbieHubAppState extends State<TarbieHubApp> {
  AppUser? _currentUser;
  UserRole? _activeRole;

  void _onLogin(AppUser user) {
    setState(() {
      _currentUser = user;
      _activeRole = user.roles.length == 1 ? user.roles.first : null;
    });
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
    setState(() {
      _currentUser = null;
      _activeRole = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'College Tarbie Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF224A9A)),
        useMaterial3: true,
      ),
      home: _currentUser == null
          ? LoginPage(onLogin: _onLogin)
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
                ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final ValueChanged<AppUser> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: '123456');
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final user = mockUsers.where((u) => u.login == _loginController.text).firstOrNull;
    if (user == null || _passwordController.text != '123456') {
      setState(() {
        _error = 'Неверный логин или пароль. Для демо используйте пароль: 123456';
      });
      return;
    }
    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('College Tarbie Hub',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Desktop MVP — вход',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Введите логин' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        border: OutlineInputBorder(),
                        helperText: 'Демо-пароль: 123456',
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Введите пароль' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          )),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Войти'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                  children: user.roles
                      .map((role) => ActionChip(
                            label: Text(role.label),
                            onPressed: () => onSelectRole(role),
                          ))
                      .toList(),
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
    this.onChangeRole,
  });

  final AppUser user;
  final UserRole role;
  final VoidCallback onLogout;
  final VoidCallback? onChangeRole;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppSection _section;

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
          AppSection.dashboard,
          AppSection.events,
          AppSection.eventDetails,
          AppSection.psychologist,
          AppSection.social,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.curator:
        return const [
          AppSection.events,
          AppSection.eventCreate,
          AppSection.eventDetails,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.psychologist:
        return const [
          AppSection.psychologist,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.socialPedagogue:
        return const [
          AppSection.social,
          AppSection.notifications,
          AppSection.profile,
        ];
      case UserRole.student:
        return const [
          AppSection.social,
          AppSection.events,
          AppSection.notifications,
          AppSection.profile,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _allowedSections(widget.role);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1280;
    final isTablet = width >= 768 && width < 1280;
    final content = _SectionContent(section: _section);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.label} • ${_section.title}'),
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
      drawer: isDesktop ? null : Drawer(child: _buildNavigationList(sections)),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              NavigationRail(
                selectedIndex: sections.indexOf(_section),
                onDestinationSelected: (index) =>
                    setState(() => _section = sections[index]),
                labelType: NavigationRailLabelType.all,
                destinations: sections
                    .map((s) =>
                        NavigationRailDestination(icon: Icon(s.icon), label: Text(s.title)))
                    .toList(),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 320),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: content),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _QuickPanel(role: widget.role),
                            ),
                          ],
                        )
                      : isTablet
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: content),
                                const SizedBox(width: 12),
                                Expanded(child: _QuickPanel(role: widget.role)),
                              ],
                            )
                          : content,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: width <= 767
          ? NavigationBar(
              selectedIndex: sections.indexOf(_section),
              destinations: sections
                  .take(4)
                  .map((s) => NavigationDestination(icon: Icon(s.icon), label: s.title))
                  .toList(),
              onDestinationSelected: (index) => setState(() => _section = sections[index]),
            )
          : null,
    );
  }

  Widget _buildNavigationList(List<AppSection> sections) {
    return ListView(
      children: [
        DrawerHeader(
          child: Text(widget.user.name, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...sections.map(
          (s) => ListTile(
            selected: _section == s,
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
  const _SectionContent({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AppSection.dashboard:
        return const _DashboardPage();
      case AppSection.events:
        return const _EventsPage();
      case AppSection.eventCreate:
        return const _EventFormPage();
      case AppSection.eventDetails:
        return const _EventDetailsPage();
      case AppSection.psychologist:
        return const _PsychologistPage();
      case AppSection.social:
        return const _SocialPage();
      case AppSection.notifications:
        return const _NotificationsPage();
      case AppSection.profile:
        return const _ProfilePage();
    }
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сводка MVP', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _MetricCard(title: 'Студентов', value: '642'),
            _MetricCard(title: 'Высокий риск', value: '28'),
            _MetricCard(title: 'Мероприятий (месяц)', value: '34'),
            _MetricCard(title: 'Заявки соцпомощи', value: '53'),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsPage extends StatelessWidget {
  const _EventsPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Список мероприятий',
      items: [
        'Отаншылдық: встреча с ветеранами — 24.04',
        'Құрмет: день наставника — 26.04',
        'Талап: дебатный турнир — 28.04',
      ],
    );
  }
}

class _EventFormPage extends StatelessWidget {
  const _EventFormPage();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Создание мероприятия', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Ценность',
                border: OutlineInputBorder(),
                hintText: 'Отаншылдық / Бірлік / Адалдық ...',
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Группа',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailsPage extends StatelessWidget {
  const _EventDetailsPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Карточка мероприятия',
      items: [
        'Куратор: Жуматай А.',
        'Группа: IS-201',
        'Участники: 21 / 24',
        'Отчет: текст + 3 фото',
      ],
    );
  }
}

class _PsychologistPage extends StatelessWidget {
  const _PsychologistPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Модуль психолога',
      items: [
        'Студент: Ержан Т. — риск: высокий',
        'Студент: Динара М. — риск: средний',
        'Фильтры: группа / курс / уровень риска',
      ],
    );
  }
}

class _SocialPage extends StatelessWidget {
  const _SocialPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Заявки соцпомощи',
      items: [
        '№A-1042 — На проверке',
        '№A-1038 — Требуется дополнение',
        '№A-1029 — Одобрено',
      ],
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Уведомления',
      items: [
        'Статус заявки №A-1038 изменен',
        'Новое мероприятие для группы IS-201',
        'Загрузите недостающие документы до 25.04',
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return const _SimpleCardList(
      title: 'Профиль пользователя',
      items: [
        'ФИО: демо-пользователь',
        'Телефон: +7 700 000 00 00',
        'Роль: зависит от выбранного контура',
      ],
    );
  }
}

class _SimpleCardList extends StatelessWidget {
  const _SimpleCardList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPanel extends StatelessWidget {
  const _QuickPanel({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Быстрые действия', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {},
              child: const Text('Создать уведомление'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Экспорт PDF отчета'),
            ),
            const SizedBox(height: 16),
            Text('Текущая роль: ${role.label}'),
          ],
        ),
      ),
    );
  }
}
