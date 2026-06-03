import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../core/skin.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../ui/theme.dart';
import '../feed/widgets/post_card.dart';
import '../post/widgets/comment_tile.dart';
import 'post_gen.dart';

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
    int total = 0;
    final dirs = [
      await _cacheDir(),
      await getTemporaryDirectory().then((t) {
        final d = Directory('${t.path}/video_thumbs');
        return d.existsSync() ? d : null;
      }),
    ];
    for (final dir in dirs) {
      if (dir == null) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
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
    try {
      await DefaultCacheManager().emptyCache();
      final dir = await _cacheDir();
      if (dir != null) await dir.delete(recursive: true);
      final tmp = await getTemporaryDirectory();
      final videoThumbsDir = Directory('${tmp.path}/video_thumbs');
      if (videoThumbsDir.existsSync()) {
        await videoThumbsDir.delete(recursive: true);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      Gif.cache.clear();
      if (mounted) {
        setState(() {
          _cacheBytes = 0;
          _clearing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _clearing = false);
    }
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
    final fontSize = ref.watch(fontSizeProvider);
    final autoLoadMedia = ref.watch(autoLoadMediaProvider);
    final autoLoadVideo = ref.watch(autoLoadVideoProvider);

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
                ),
                RadioListTile(
                  value: AppSkin.yellow,
                  title: Text('Жёлтый (классика)'),
                ),
                RadioListTile(value: AppSkin.pink, title: Text('Розовый')),
                RadioListTile(value: AppSkin.dark, title: Text('Тёмный')),
              ],
            ),
          ),

          // ── Текст ─────────────────────────────────────────────────────────
          const _SectionHeader('Текст'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              min: 11,
              max: 20,
              divisions: 9,
              value: fontSize,
              onChanged: (v) => ref.read(fontSizeProvider.notifier).set(v),
            ),
          ),
          _TextSizePreview(skin: skin, fontSize: fontSize),

          // ── Медиа ─────────────────────────────────────────────────────────
          const _SectionHeader('Медиа'),
          SwitchListTile(
            title: const Text('Автозагрузка GIF'),
            subtitle: const Text('При отключении — загрузка по кнопке'),
            value: autoLoadMedia,
            onChanged: (v) => ref.read(autoLoadMediaProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: const Text('Автозагрузка видео'),
            subtitle: const Text('При отключении — превью с кнопкой Play'),
            value: autoLoadVideo,
            onChanged: (v) => ref.read(autoLoadVideoProvider.notifier).set(v),
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

class _TextSizePreview extends StatefulWidget {
  const _TextSizePreview({required this.skin, required this.fontSize});

  final AppSkin skin;
  final double fontSize;

  @override
  State<_TextSizePreview> createState() => _TextSizePreviewState();
}

class _TextSizePreviewState extends State<_TextSizePreview> {
  late Post _post;
  late List<Comment> _comments;

  @override
  void initState() {
    super.initState();
    final preview = generateSettingsPreview(commentCount: 2);
    _post = preview.post;
    _comments = preview.comments;
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeForSkin(widget.skin);
    final scale = widget.fontSize / FontSizeNotifier.defaultSize;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Theme(
        data: theme,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: IgnorePointer(
              child: Column(
                children: [
                  PostCard(
                    post: _post,
                    onTap: () {},
                    showApproverTap: false,
                    showVoteSection: false,
                  ),
                  for (final c in _comments) CommentTile(comment: c),
                ],
              ),
            ),
          ),
        ),
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
