import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:forge2d/forge2d.dart' hide Transform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/build_info.dart';
import '../../../ui/widgets/blur_app_bar.dart';

const _physicsScale = 80.0;
const _returnDuration = Duration(milliseconds: 650);
const _dragEnableDelay = Duration(milliseconds: 900);
const _topThrowPocketHeight = 2400.0;

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  int _tapCount = 0;
  DateTime _lastTap = DateTime(0);

  bool _easterEggActive = false;
  bool _returningHome = false;
  Color _bgColor = Colors.white;
  List<_Word> _words = [];
  ui.Image? _logoImage;
  World? _world;
  Ticker? _ticker;
  Duration _lastTickTime = Duration.zero;
  Duration _startedAt = Duration.zero;
  DateTime? _easterEggStartedAt;
  double _screenWidth = 0, _screenHeight = 0;
  final _random = Random();
  _Word? _draggedWord;
  Offset _lastDragPosition = Offset.zero;
  DateTime? _lastDragTime;
  Offset _dragVelocity = Offset.zero;

  final _stackKey = GlobalKey();
  final _logoKey = GlobalKey();
  final _titleKey = GlobalKey();
  final _subtitleKey = GlobalKey();
  final _easterTextKey = GlobalKey();
  final _infoVersionKeys = [GlobalKey(), GlobalKey()];
  final _infoBuildKeys = [GlobalKey(), GlobalKey()];
  final _infoDateKeys = [GlobalKey(), GlobalKey()];
  final _infoAuthorKeys = [GlobalKey(), GlobalKey()];
  final _dividerKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  final _linkIconKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  final _linkTitleKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  final _linkSubtitleKeys = List<GlobalKey>.generate(4, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    _loadLogoImage();
  }

  Future<void> _loadLogoImage() async {
    final data = await rootBundle.load('assets/splash.png');
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
    final image = await completer.future;
    if (mounted) {
      setState(() => _logoImage = image);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > const Duration(milliseconds: 800)) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;
    if (_tapCount >= 5) {
      _tapCount = 0;
      _startEasterEgg();
    }
  }

  Future<void> _startEasterEgg() async {
    if (_logoImage == null) {
      await _loadLogoImage();
      if (!mounted) return;
    }

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final cs = Theme.of(context).colorScheme;
    _screenWidth = stackBox.size.width;
    _screenHeight = stackBox.size.height;
    _bgColor = cs.surface;

    _words = _collectWords(stackBox, cs);
    _setupWorld();

    _returningHome = false;
    _easterEggStartedAt = DateTime.now();
    _lastTickTime = Duration.zero;
    _startedAt = Duration.zero;
    _ticker?.dispose();
    _ticker = Ticker(_onTick)..start();
    setState(() => _easterEggActive = true);
  }

  List<_Word> _collectWords(RenderBox stackBox, ColorScheme cs) {
    final result = <_Word>[];

    void add(GlobalKey key, Color color, TextStyle? style) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro == null || ro is! RenderParagraph || !ro.hasSize) return;
      final text = ro.text.toPlainText().trim();
      if (text.isEmpty) return;
      final pos = stackBox.globalToLocal(ro.localToGlobal(Offset.zero));
      if (pos.dy > _screenHeight || pos.dy + ro.size.height < 0) return;
      final matches = RegExp(r'\S+').allMatches(text);
      for (final match in matches) {
        final boxes = ro.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
        if (boxes.isEmpty) continue;
        final left = boxes.map((box) => box.left).reduce(min);
        final top = boxes.map((box) => box.top).reduce(min);
        final right = boxes.map((box) => box.right).reduce(max);
        final bottom = boxes.map((box) => box.bottom).reduce(max);
        final width = max(right - left, 4.0);
        final height = max(bottom - top, 4.0);
        final order = result.length;
        result.add(
          _Word(
            text: match.group(0)!,
            color: color,
            style: style,
            w: width,
            h: height,
            x: pos.dx + left + width / 2,
            y: pos.dy + top + height / 2,
            initialVelocity: Vector2(
              (_random.nextDouble() - 0.5) * 1.2,
              -0.8 - _random.nextDouble() * 1.4,
            ),
            initialAngularVelocity: (_random.nextDouble() - 0.5) * 5,
            delay: order * 0.035 + _random.nextDouble() * 0.16,
          ),
        );
      }
    }

    void addBox({
      required GlobalKey key,
      required Color color,
      IconData? icon,
      ui.Image? image,
      double? iconSize,
      bool isLine = false,
      double? lineThickness,
    }) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro == null || ro is! RenderBox || !ro.hasSize) return;
      final pos = stackBox.globalToLocal(ro.localToGlobal(Offset.zero));
      if (pos.dy > _screenHeight || pos.dy + ro.size.height < 0) return;
      final order = result.length;
      final height = lineThickness ?? ro.size.height;
      result.add(
        _Word(
          color: color,
          icon: icon,
          image: image,
          iconSize: iconSize,
          isLine: isLine,
          lineThickness: lineThickness,
          w: max(ro.size.width, 4.0),
          h: max(height, 1.0),
          x: pos.dx + ro.size.width / 2,
          y: pos.dy + ro.size.height / 2,
          initialVelocity: Vector2(
            (_random.nextDouble() - 0.5) * 1.2,
            -0.8 - _random.nextDouble() * 1.4,
          ),
          initialAngularVelocity: (_random.nextDouble() - 0.5) * 5,
          delay: order * 0.035 + _random.nextDouble() * 0.16,
        ),
      );
    }

    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final linkStyle = Theme.of(context).textTheme.titleMedium;
    final linkSubtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final dividerColor = cs.outlineVariant.withValues(alpha: 0.55);
    final iconColor = IconTheme.of(context).color ?? cs.onSurfaceVariant;
    addBox(key: _logoKey, color: cs.onSurface, image: _logoImage);
    add(_titleKey, cs.onSurface, titleStyle);
    add(_subtitleKey, cs.outline, bodySmall?.copyWith(color: cs.outline));
    for (final keys in [
      _infoVersionKeys,
      _infoBuildKeys,
      _infoDateKeys,
      _infoAuthorKeys,
    ]) {
      add(keys[0], cs.outline, bodySmall?.copyWith(color: cs.outline));
      add(keys[1], cs.onSurface, bodySmall);
    }
    add(
      _easterTextKey,
      cs.outlineVariant,
      bodySmall?.copyWith(color: cs.outlineVariant, fontSize: 10),
    );
    for (final key in _dividerKeys) {
      addBox(
        key: key,
        color: dividerColor,
        isLine: true,
        lineThickness: DividerTheme.of(context).thickness ?? 1,
      );
    }
    for (final key in _linkTitleKeys) {
      add(key, cs.onSurface, linkStyle);
    }
    for (final key in _linkSubtitleKeys) {
      add(key, cs.onSurfaceVariant, linkSubtitleStyle);
    }
    final icons = [
      Icons.language_outlined,
      Icons.campaign_outlined,
      Icons.forum_outlined,
      Icons.telegram,
      Icons.bug_report_outlined,
    ];
    for (var i = 0; i < _linkIconKeys.length; i++) {
      addBox(
        key: _linkIconKeys[i],
        color: iconColor,
        icon: icons[i],
        iconSize: 24,
      );
    }
    return result;
  }

  void _setupWorld() {
    _world = World(Vector2(0, 24));

    final sw = _screenWidth;
    final sh = _screenHeight;
    _wall(sw / 2, -_topThrowPocketHeight - 8, sw / 2, 8);
    _wall(sw / 2, sh + 8, sw / 2, 8);
    _wall(
      -8,
      (sh - _topThrowPocketHeight) / 2,
      8,
      (sh + _topThrowPocketHeight) / 2,
    );
    _wall(
      sw + 8,
      (sh - _topThrowPocketHeight) / 2,
      8,
      (sh + _topThrowPocketHeight) / 2,
    );

    for (final word in _words) {
      final body = _world!.createBody(
        BodyDef(
          type: BodyType.kinematic,
          position: Vector2(word.x / _physicsScale, word.y / _physicsScale),
          linearDamping: 0.08,
          angularDamping: 0.12,
          allowSleep: true,
        ),
      );
      body.createFixture(
        FixtureDef(
          PolygonShape()..setAsBoxXY(
            max(word.w / 2, 3) / _physicsScale,
            max(word.h / 2, 3) / _physicsScale,
          ),
          density: 0.75,
          friction: 0.58,
          restitution: 0.18,
        ),
      );
      word.body = body;
    }
  }

  void _wall(double cx, double cy, double hw, double hh) {
    final body = _world!.createBody(
      BodyDef(position: Vector2(cx / _physicsScale, cy / _physicsScale)),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(hw / _physicsScale, hh / _physicsScale),
        friction: 0.72,
        restitution: 0.22,
      ),
    );
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      _startedAt = elapsed;
      return;
    }
    final dt = min((elapsed - _lastTickTime).inMilliseconds / 1000.0, 1 / 30);
    _lastTickTime = elapsed;
    final runTime = (elapsed - _startedAt).inMilliseconds / 1000.0;

    if (_returningHome) {
      final t =
          ((elapsed - _startedAt).inMicroseconds /
                  _returnDuration.inMicroseconds)
              .clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(t);

      for (final word in _words) {
        word.x = ui.lerpDouble(word.returnX, word.homeX, eased)!;
        word.y = ui.lerpDouble(word.returnY, word.homeY, eased)!;
        word.angle = ui.lerpDouble(word.returnAngle, 0, eased)!;
      }

      if (t >= 1) {
        _ticker?.stop();
        _world = null;
        if (mounted) {
          setState(() {
            _easterEggActive = false;
            _returningHome = false;
          });
        }
        return;
      }
    } else {
      for (final word in _words) {
        final body = word.body;
        if (body == null ||
            word.released ||
            word == _draggedWord ||
            runTime < word.delay) {
          continue;
        }
        word.released = true;
        body.setType(BodyType.dynamic);
        body.linearVelocity = word.initialVelocity;
        body.angularVelocity = word.initialAngularVelocity;
      }

      _world?.stepDt(dt);

      for (final word in _words) {
        final body = word.body;
        if (body != null) {
          word.x = body.position.x * _physicsScale;
          word.y = body.position.y * _physicsScale;
          word.angle = body.angle;
        }
      }
    }

    if (mounted) setState(() {});
  }

  void _cancelEasterEgg() {
    if (_returningHome) return;
    _draggedWord = null;
    for (final word in _words) {
      word.returnX = word.x;
      word.returnY = word.y;
      word.returnAngle = atan2(sin(word.angle), cos(word.angle));
      word.body = null;
    }
    _world = null;
    _easterEggStartedAt = null;
    _returningHome = true;
    _startedAt = Duration.zero;
    _lastTickTime = Duration.zero;
    _ticker?.dispose();
    _ticker = Ticker(_onTick)..start();
    setState(() {});
  }

  void _onPanStart(DragStartDetails details) {
    if (_returningHome || !_dragEnabled) return;
    final word = _hitTestWord(details.localPosition);
    final body = word?.body;
    if (word == null || body == null) return;

    _draggedWord = word;
    _lastDragPosition = details.localPosition;
    _lastDragTime = DateTime.now();
    _dragVelocity = Offset.zero;
    word.released = true;
    body.setType(BodyType.kinematic);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
    body.setTransform(
      Vector2(
        details.localPosition.dx / _physicsScale,
        details.localPosition.dy / _physicsScale,
      ),
      word.angle,
    );
  }

  bool get _dragEnabled {
    final startedAt = _easterEggStartedAt;
    return _easterEggActive &&
        startedAt != null &&
        DateTime.now().difference(startedAt) >= _dragEnableDelay;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final word = _draggedWord;
    final body = word?.body;
    if (word == null || body == null) return;

    final now = DateTime.now();
    final lastTime = _lastDragTime;
    final dt = lastTime == null
        ? 0.0
        : now.difference(lastTime).inMicroseconds /
              Duration.microsecondsPerSecond;
    if (dt > 0) {
      _dragVelocity = (details.localPosition - _lastDragPosition) / dt;
    }
    _lastDragPosition = details.localPosition;
    _lastDragTime = now;

    body.setTransform(
      Vector2(
        details.localPosition.dx / _physicsScale,
        details.localPosition.dy / _physicsScale,
      ),
      word.angle,
    );
    word.x = details.localPosition.dx;
    word.y = details.localPosition.dy;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _releaseDraggedWord(details.velocity.pixelsPerSecond);
  }

  void _onPanCancel() {
    _releaseDraggedWord(_dragVelocity);
  }

  void _releaseDraggedWord(Offset velocity) {
    final word = _draggedWord;
    final body = word?.body;
    if (word == null || body == null) return;

    body.setType(BodyType.dynamic);
    final throwVelocity =
        velocity.distanceSquared > _dragVelocity.distanceSquared
        ? velocity
        : _dragVelocity;
    body.linearVelocity = Vector2(
      throwVelocity.dx / _physicsScale,
      throwVelocity.dy / _physicsScale,
    );
    body.angularVelocity = (throwVelocity.dx / _physicsScale).clamp(-8.0, 8.0);
    _draggedWord = null;
  }

  _Word? _hitTestWord(Offset point) {
    for (final word in _words.reversed) {
      if (word.body == null) continue;
      final dx = point.dx - word.x;
      final dy = point.dy - word.y;
      final cosA = cos(-word.angle);
      final sinA = sin(-word.angle);
      final localX = dx * cosA - dy * sinA;
      final localY = dx * sinA + dy * cosA;
      final padding = word.isLine ? 12.0 : 8.0;
      if (localX.abs() <= word.w / 2 + padding &&
          localY.abs() <= word.h / 2 + padding) {
        return word;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: Stack(
        key: _stackKey,
        children: [
          if (!_easterEggActive)
            ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 24 + landscapeHPadding(context),
                vertical: 32,
              ),
              children: [
                GestureDetector(
                  onTap: _onLogoTap,
                  child: Image.asset(
                    key: _logoKey,
                    'assets/splash.png',
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    key: _titleKey,
                    'Свалко',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    key: _subtitleKey,
                    'Неофициальный клиент svalko.org',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Divider(key: _dividerKeys[0]),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Версия',
                  value: _version.isEmpty ? '…' : _version,
                  labelKey: _infoVersionKeys[0],
                  valueKey: _infoVersionKeys[1],
                ),
                if (buildHash.isNotEmpty)
                  _InfoRow(
                    label: 'Билд',
                    value: buildHash,
                    labelKey: _infoBuildKeys[0],
                    valueKey: _infoBuildKeys[1],
                  ),
                if (buildDate.isNotEmpty)
                  _InfoRow(
                    label: 'Дата сборки',
                    value: buildDate,
                    labelKey: _infoDateKeys[0],
                    valueKey: _infoDateKeys[1],
                  ),
                _InfoRow(
                  label: 'Автор',
                  value: 'bzdno',
                  labelKey: _infoAuthorKeys[0],
                  valueKey: _infoAuthorKeys[1],
                ),
                const SizedBox(height: 8),
                Divider(key: _dividerKeys[1]),
                const SizedBox(height: 8),
                Text(
                  key: _easterTextKey,
                  'А НЕЧИСТЫМ ПРОГРАММИСТАМ ТРАМПАМПАМ ТРАМПАМПАМ!!!1 ОППА!111АДИНАДИН',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outlineVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Divider(key: _dividerKeys[2]),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.language_outlined, key: _linkIconKeys[0]),
                  title: Text(key: _linkTitleKeys[0], 'svalko.org'),
                  subtitle: Text(key: _linkSubtitleKeys[0], 'Открыть сайт'),
                  onTap: () => launchUrl(
                    Uri.parse('https://svalko.org'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.campaign_outlined, key: _linkIconKeys[1]),
                  title: Text(key: _linkTitleKeys[1], 't.me/svalko_android'),
                  subtitle: Text(key: _linkSubtitleKeys[1], 'Новости и релизы'),
                  onTap: () => launchUrl(
                    Uri.parse('https://t.me/svalko_android'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.forum_outlined, key: _linkIconKeys[2]),
                  title: Text(
                    key: _linkTitleKeys[2],
                    't.me/svalko_android_backlog',
                  ),
                  subtitle: Text(
                    key: _linkSubtitleKeys[2],
                    'Багрепорты и фичреквесты',
                  ),
                  onTap: () => launchUrl(
                    Uri.parse('https://t.me/svalko_android_backlog'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.telegram, key: _linkIconKeys[3]),
                  title: Text(key: _linkTitleKeys[3], 't.me/svalo4ka'),
                  subtitle: Text(
                    key: _linkSubtitleKeys[3],
                    'Общество защиты низкорослых победилов',
                  ),
                  onTap: () => launchUrl(
                    Uri.parse('https://t.me/svalo4ka'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.bug_report_outlined,
                    key: _linkIconKeys[4],
                  ),
                  title: Text(key: _linkTitleKeys[4], 'Логи'),
                  onTap: () => Navigator.of(context).pushNamed('/logs'),
                ),
              ],
            ),
          if (_easterEggActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanCancel,
                child: CustomPaint(
                  painter: _GamePainter(words: _words, bgColor: _bgColor),
                ),
              ),
            ),
          if (_easterEggActive)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _returningHome ? null : _cancelEasterEgg,
              ),
            ),
        ],
      ),
    );
  }
}

class _Word {
  final String? text;
  final IconData? icon;
  final ui.Image? image;
  final Color color;
  final TextStyle? style;
  final double? iconSize;
  final bool isLine;
  final double? lineThickness;
  final double w, h;
  final double delay;
  final Vector2 initialVelocity;
  final double initialAngularVelocity;
  double x, y, angle;
  late final double homeX;
  late final double homeY;
  double returnX = 0;
  double returnY = 0;
  double returnAngle = 0;
  Body? body;
  bool released;

  _Word({
    this.text,
    this.icon,
    this.image,
    required this.color,
    this.style,
    this.iconSize,
    this.isLine = false,
    this.lineThickness,
    required this.w,
    required this.h,
    required this.x,
    required this.y,
    required this.initialVelocity,
    required this.initialAngularVelocity,
    required this.delay,
  }) : angle = 0,
       released = false {
    homeX = x;
    homeY = y;
  }
}

class _GamePainter extends CustomPainter {
  final List<_Word> words;
  final Color bgColor;

  const _GamePainter({required this.words, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final w in words) {
      canvas.save();
      canvas.translate(w.x, w.y);
      canvas.rotate(w.angle);
      if (w.isLine) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: w.w,
            height: w.lineThickness ?? w.h,
          ),
          Paint()..color = w.color,
        );
      } else if (w.image != null) {
        paintImage(
          canvas: canvas,
          rect: Rect.fromCenter(center: Offset.zero, width: w.w, height: w.h),
          image: w.image!,
          fit: BoxFit.contain,
        );
      } else if (w.icon != null) {
        final icon = w.icon!;
        tp.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            color: w.color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: w.iconSize ?? min(w.w, w.h),
            decoration: TextDecoration.none,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      } else if (w.text != null) {
        tp.text = TextSpan(
          text: w.text,
          style: (w.style ?? const TextStyle()).copyWith(
            color: w.color,
            decoration: TextDecoration.none,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.labelKey,
    this.valueKey,
  });

  final String label;
  final String value;
  final GlobalKey? labelKey;
  final GlobalKey? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key: labelKey,
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(key: valueKey, value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
