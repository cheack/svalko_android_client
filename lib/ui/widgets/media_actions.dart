import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';

final _dio = Dio();

AppStrings _s(BuildContext context) => AppStrings.of(
      ProviderScope.containerOf(context).read(languageProvider),
    );

Future<String> _downloadToTemp(String url) async {
  final dir = await getTemporaryDirectory();
  final filename = url.split('/').last.split('?').first;
  final path = '${dir.path}/$filename';
  await _dio.download(url, path);
  return path;
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  required String successMsg,
  required String errorPrefix,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await action();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(successMsg)));
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text('$errorPrefix: $e')));
  }
}

Future<void> saveMedia(
  BuildContext context,
  String url, {
  bool isVideo = false,
}) {
  final s = _s(context);
  return _run(
    context,
    () async {
      final path = await _downloadToTemp(url);
      if (isVideo) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }
    },
    successMsg: isVideo ? s.videoSaved : s.photoSaved,
    errorPrefix: s.unknownError,
  );
}

Future<void> shareMedia(
  BuildContext context,
  String url, {
  bool isVideo = false,
}) {
  final s = _s(context);
  return _run(
    context,
    () async {
      final path = await _downloadToTemp(url);
      await Share.shareXFiles([XFile(path)]);
    },
    successMsg: s.share,
    errorPrefix: s.unknownError,
  );
}

Future<void> showMediaSheet(
  BuildContext context,
  String url, {
  bool isVideo = false,
}) {
  final s = _s(context);
  return showModalBottomSheet<void>(
    context: context,
    routeSettings: const RouteSettings(name: '/media-actions'),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(isVideo ? s.saveVideo : s.savePhoto),
            onTap: () {
              Navigator.pop(sheetCtx);
              saveMedia(context, url, isVideo: isVideo);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(s.share),
            onTap: () {
              Navigator.pop(sheetCtx);
              shareMedia(context, url, isVideo: isVideo);
            },
          ),
        ],
      ),
    ),
  );
}
