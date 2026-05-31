import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../core/skin.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _cacheBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final dir = await _cacheDir();
    if (dir == null) {
      if (mounted) setState(() => _cacheBytes = 0);
      return;
    }
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    if (mounted) setState(() => _cacheBytes = total);
  }

  Future<Directory?> _cacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/${DefaultCacheManager.key}');
    return dir.existsSync() ? dir : null;
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    await DefaultCacheManager().emptyCache();
    final dir = await _cacheDir();
    if (dir != null) await dir.delete(recursive: true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    Gif.cache.clear();
    if (mounted) setState(() { _cacheBytes = 0; _clearing = false; });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
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

          // ── Кэш ───────────────────────────────────────────────────────────
          const _SectionHeader('Кэш'),
          ListTile(
            title: const Text('Размер кэша'),
            subtitle: Text(
              _cacheBytes == null ? 'Подсчёт...' : _formatBytes(_cacheBytes!),
            ),
            trailing: _clearing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _cacheBytes == 0 ? null : _clearCache,
                    child: const Text('Очистить'),
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
