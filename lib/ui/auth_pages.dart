import 'package:flutter/material.dart';

import '../auth/password_policy.dart';
import '../data/app_database.dart';
import '../models/app_user.dart';
import '../models/student_group.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});

  final ValueChanged<AppUser> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final user = await AppDatabase.instance.login(
        _loginController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _error = 'Неверный логин или пароль';
          _busy = false;
        });
        return;
      }
      widget.onLoggedIn(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка входа: $e';
        _busy = false;
      });
    }
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
                    Text('College Tarbie Hub', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Вход в систему', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _loginController,
                      textInputAction: TextInputAction.next,
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
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Введите пароль' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Войти'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  ),
                          child: const Text('Регистрация'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PasswordResetPage(),
                                    ),
                                  ),
                          child: const Text('Забыли пароль?'),
                        ),
                      ],
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

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});

  final String password;

  static const _labels = <String>['Очень слабо', 'Слабо', 'Средне', 'Хорошо', 'Сильно'];

  @override
  Widget build(BuildContext context) {
    final n = PasswordPolicy.strengthBars(password);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          password.isEmpty ? 'Надёжность пароля' : 'Надёжность: ${_labels[n]}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (i) {
            final on = i < n;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: LinearProgressIndicator(
                  value: on ? 1 : 0.15,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: on ? scheme.primary : scheme.surfaceContainerHighest,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _error;
  bool _busy = false;
  List<StudentGroup> _groups = <StudentGroup>[];
  int? _groupId;
  bool _loadingGroups = true;

  @override
  void initState() {
    super.initState();
    _pass.addListener(() => setState(() {}));
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final list = await AppDatabase.instance.listStudentGroups();
      if (!mounted) return;
      setState(() {
        _groups = list;
        _loadingGroups = false;
        if (_groupId != null && !list.any((g) => g.id == _groupId)) {
          _groupId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGroups = false;
        _error = 'Не удалось загрузить группы: $e';
      });
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _email.dispose();
    _name.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  String? _validatePasswordField(String? v) {
    if (v == null || v.isEmpty) return 'Введите пароль';
    return PasswordPolicy.validate(v);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_groupId == null) {
      setState(() => _error = 'Выберите группу');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await AppDatabase.instance.register(
      login: _login.text,
      displayName: _name.text,
      email: _email.text,
      groupId: _groupId!,
      password: _pass.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _busy = false;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Регистрация успешна. Войдите под своим логином.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadingGroups)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_loadingGroups && _groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Пока нет ни одной группы. Попросите администратора добавить группы '
                        'в админ-панели, затем откройте регистрацию снова.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  TextFormField(
                    controller: _login,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.length < 3 ? 'Не короче 3 символов' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 5) return 'Введите email';
                      if (!v.contains('@') || !v.contains('.')) return 'Некорректный email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().length < 2 ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Группа',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        hint: const Text('Выберите группу'),
                        value: _groupId,
                        items: _groups
                            .map(
                              (g) => DropdownMenuItem<int>(
                                value: g.id,
                                child: Text(g.name),
                              ),
                            )
                            .toList(),
                        onChanged: _groups.isEmpty
                            ? null
                            : (v) => setState(() => _groupId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePasswordField,
                  ),
                  const SizedBox(height: 8),
                  _PasswordStrengthBar(password: _pass.text),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass2,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повтор пароля',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != _pass.text ? 'Пароли не совпадают' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_busy || _loadingGroups || _groups.isEmpty) ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  int _step = 0;
  final _login = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pass.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _login.dispose();
    _code.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_login.text.trim().isEmpty) {
      setState(() => _error = 'Введите логин');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await AppDatabase.instance.requestPasswordResetForLogin(_login.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код отправлен на email, указанный при регистрации (проверьте «Спам»).')),
    );
    setState(() => _step = 1);
  }

  Future<void> _applyNewPassword() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Введите код');
      return;
    }
    final pe = PasswordPolicy.validate(_pass.text);
    if (pe != null) {
      setState(() => _error = pe);
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await AppDatabase.instance.completePasswordReset(
      login: _login.text,
      code: _code.text,
      newPassword: _pass.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пароль обновлён. Войдите с новым паролем.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сброс пароля')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  TextField(
                    controller: _login,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _requestCode,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отправить код на почту'),
                  ),
                ] else ...[
                  Text('Логин: ${_login.text}', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'Код из письма',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PasswordStrengthBar(password: _pass.text),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass2,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Повтор нового пароля',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _applyNewPassword,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить новый пароль'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
