import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../core/skin.dart';
import '../feed/feed_controller.dart';
import '../navigation/tags_cache.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../ui/theme.dart';
import '../feed/widgets/post_card.dart';
import '../news/news_settings_controller.dart';
import 'debug_crash_tile.dart';
import 'debug_news_tile.dart';
import '../notifications/notification_service.dart';
import '../post/widgets/comment_tile.dart';
import 'post_gen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  int? _cacheBytes;
  bool _clearing = false;
  bool? _notificationsAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCacheSize();
    _loadNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadNotificationPermission();
  }

  Future<void> _loadNotificationPermission() async {
    final allowed =
        await NotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsAllowed = allowed);
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationService.instance.openNotificationSettings();
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
      await ref.read(tagsCacheProvider.notifier).clearAndRefetch();
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

    final autoLoadMedia = ref.watch(autoLoadMediaProvider);
    final autoLoadVideo = ref.watch(autoLoadVideoProvider);
    final siteMode = ref.watch(siteModeProvider);
    final newsNotifications = ref.watch(newsNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Theme(
        data: Theme.of(context).copyWith(
          visualDensity: const VisualDensity(vertical: -2),
        ),
        child: ListView(
        children: [
          // ── Режим ─────────────────────────────────────────────────────────
          const _SectionHeader('Режим'),
          RadioGroup<SiteMode>(
            groupValue: siteMode,
            onChanged: (v) {
              if (v != null) {
                ref.read(siteModeProvider.notifier).set(v);
                ref.read(calendarStateProvider.notifier).state =
                    (month: null, selectedPath: null);
              }
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: SiteMode.svalko,
                  title: Text('Свалка'),
                ),
                RadioListTile(
                  value: SiteMode.taSvalko,
                  title: Text('Та свалка'),
                ),
              ],
            ),
          ),

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
          _TextSizeSection(skin: skin),

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

          // ── Новости ───────────────────────────────────────────────────────
          const _SectionHeader('Новости'),
          SwitchListTile(
            title: const Text('Уведомлять о новых постах'),
            value: newsNotifications,
            onChanged: (v) async {
              await ref.read(newsNotificationsProvider.notifier).set(v);
              if (v) {
                await NotificationService.instance.requestNotificationsPermission();
              }
              await _loadNotificationPermission();
            },
          ),
          if (newsNotifications && _notificationsAllowed == false)
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Уведомления выключены в системе'),
              subtitle: const Text('Без разрешения новые посты не появятся в шторке'),
              trailing: TextButton(
                onPressed: _requestNotificationPermission,
                child: const Text('Разрешить'),
              ),
            ),

          // ── Debug ─────────────────────────────────────────────────────────
          if (kDebugMode) ...[
            const _SectionHeader('Debug'),
            const DebugNewsTile(),
            const DebugCrashTile(),
          ],

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
      ),
    );
  }
}

class _TextSizeSection extends ConsumerStatefulWidget {
  const _TextSizeSection({required this.skin});
  final AppSkin skin;

  @override
  ConsumerState<_TextSizeSection> createState() => _TextSizeSectionState();
}

class _TextSizeSectionState extends ConsumerState<_TextSizeSection> {
  double? _local;

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(fontSizeProvider);
    final display = _local ?? fontSize;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            min: 11,
            max: 20,
            divisions: 9,
            value: display,
            onChanged: (v) => setState(() => _local = v),
            onChangeEnd: (v) {
              ref.read(fontSizeProvider.notifier).set(v);
              setState(() => _local = null);
            },
          ),
        ),
        _TextSizePreview(skin: widget.skin, fontSize: display),
      ],
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
      padding: const EdgeInsets.only(bottom: 8),
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
                  for (final c in _comments) CommentTile(comment: c, currentPage: 0),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
