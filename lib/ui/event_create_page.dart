import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/app_user.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({
    super.key,
    required this.author,
    required this.activeRole,
    required this.onPublished,
  });

  final AppUser author;
  final UserRole activeRole;
  final VoidCallback onPublished;

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _group = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _value.dispose();
    _group.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.activeRole.canCreateEvents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Создавать мероприятия могут куратор и выше')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AppDatabase.instance.createEventAndNotifyAll(
        authorId: widget.author.id,
        title: _title.text,
        description: _description.text,
        valueTag: _value.text,
        groupName: _group.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Мероприятие опубликовано. Всем отправлено уведомление.')),
      );
      _title.clear();
      _description.clear();
      _value.clear();
      _group.clear();
      widget.onPublished();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activeRole.canCreateEvents) {
      return const Center(
        child: Text('Создание мероприятий доступно с роли «Куратор» и выше.'),
      );
    }
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Новое мероприятие', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().length < 8 ? 'Опишите подробнее (от 8 символов)' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _value,
                  decoration: const InputDecoration(
                    labelText: 'Ценность / тема',
                    hintText: 'Отаншылдық, Бірлік, Тәрбие…',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Укажите ценность' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _group,
                  decoration: const InputDecoration(
                    labelText: 'Группа / аудитория',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Укажите группу или охват' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Опубликовать в ленте'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
