import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../core/skin.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final skin = ref.watch(skinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          // ── Язык ──────────────────────────────────────────────────────────
          const _SectionHeader('Язык'),
          RadioGroup<AppLanguage>(
            groupValue: lang,
            onChanged: (v) {
              if (v != null) ref.read(languageProvider.notifier).set(v);
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: AppLanguage.svalko,
                  title: Text('Свалочный'),
                  subtitle: Text('насрано 5 раз'),
                ),
                RadioListTile(
                  value: AppLanguage.ru,
                  title: Text('Русский'),
                  subtitle: Text('5 комментариев'),
                ),
              ],
            ),
          ),

          // ── Скин ──────────────────────────────────────────────────────────
          const _SectionHeader('Скин'),
          RadioGroup<AppSkin>(
            groupValue: skin,
            onChanged: (v) {
              if (v != null) ref.read(skinProvider.notifier).set(v);
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: AppSkin.blue,
                  title: Text('Синий (спасибо Татьяне)'),
                  subtitle: Text('Светлая тема, как на сайте'),
                ),
                RadioListTile(
                  value: AppSkin.dark,
                  title: Text('Тёмный'),
                  subtitle: Text('Для чтения ночью'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
