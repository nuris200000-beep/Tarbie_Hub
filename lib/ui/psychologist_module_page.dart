import 'package:flutter/material.dart';

class PsychologistModulePage extends StatefulWidget {
  const PsychologistModulePage({super.key});

  @override
  State<PsychologistModulePage> createState() => _PsychologistModulePageState();
}

class _PsychologistModulePageState extends State<PsychologistModulePage> {
  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      text: 'Привет! Я AI-помощник. Опиши, что тебя беспокоит, и я подскажу первый шаг.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _useQuickReply(_QuickIssue issue) {
    setState(() {
      _messages.add(_ChatMessage(text: issue.title, isUser: true));
      _messages.add(_ChatMessage(text: issue.aiHint, isUser: false));
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(
        const _ChatMessage(
          text:
              'Спасибо, что написал(а). Попробуй сегодня: 1) назвать эмоцию, 2) сделать паузу 5 минут, 3) обратиться к школьному психологу, если становится тяжелее.',
          isUser: false,
        ),
      );
    });
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final issues = <_QuickIssue>[
      const _QuickIssue(
        title: 'Тревога и стресс',
        subtitle: 'Перед экзаменами, дедлайнами и оценками',
        icon: Icons.bolt_rounded,
        aiHint:
            'Если тревога высокая, попробуй дыхание 4-4-4-4 и раздели задачи на 15-минутные блоки. Если состояние держится больше недели — лучше записаться к психологу.',
      ),
      const _QuickIssue(
        title: 'Конфликты с родителями',
        subtitle: 'Ссоры дома, непонимание и давление',
        icon: Icons.family_restroom_rounded,
        aiHint:
            'В конфликте помогает формат: «Я чувствую... когда... и мне важно...». Начни разговор в спокойное время, а не в момент спора.',
      ),
      const _QuickIssue(
        title: 'Буллинг и одиночество',
        subtitle: 'Насмешки, изоляция, страх в коллективе',
        icon: Icons.groups_2_rounded,
        aiHint:
            'Не оставайся с этим один(одна): зафиксируй факты, сообщи куратору/психологу и выбери 1-2 безопасных взрослых для поддержки.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Text(
          'Быстрые ответы',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...issues.map(
          (issue) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _useQuickReply(issue),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
                      child: Icon(issue.icon, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 3),
                          Text(issue.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Чат с ИИ',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: m.isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            m.text,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: m.isUser ? Colors.white : null,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Напиши, что тебя тревожит...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sendMessage,
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Связь с психологом',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.psychology_alt_outlined)),
                  title: const Text('Психолог колледжа'),
                  subtitle: const Text('Пн–Пт, 09:00–18:00'),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Открыта запись к психологу')),
                      );
                    },
                    child: const Text('Записаться'),
                  ),
                ),
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Позвонить'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Написать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickIssue {
  const _QuickIssue({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.aiHint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String aiHint;
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}
