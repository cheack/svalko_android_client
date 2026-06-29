import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'breadcrumb_collector.dart';

const _defaultWorkerUrl = String.fromEnvironment('CRASH_HANDLER_URL');
const _defaultAppSecret = String.fromEnvironment('APP_SECRET');

class CrashReporter {
  CrashReporter._({
    Dio? dio,
    String workerUrl = _defaultWorkerUrl,
    String appSecret = _defaultAppSecret,
    BreadcrumbCollector? breadcrumbs,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            )),
        _workerUrl = workerUrl,
        _appSecret = appSecret,
        _breadcrumbs = breadcrumbs ?? BreadcrumbCollector.instance;

  static final instance = CrashReporter._();

  @visibleForTesting
  static CrashReporter test({
    required Dio dio,
    String workerUrl = 'http://test',
    String appSecret = 'secret',
    BreadcrumbCollector? breadcrumbs,
  }) =>
      CrashReporter._(
        dio: dio,
        workerUrl: workerUrl,
        appSecret: appSecret,
        breadcrumbs: breadcrumbs ?? BreadcrumbCollector(),
      );

  final Dio _dio;
  final String _workerUrl;
  final String _appSecret;
  final BreadcrumbCollector _breadcrumbs;

  String? _appVersion;
  String? _deviceInfo;
  String? _lastReportedHash;

  Future<void> init() async {
    if (_appSecret.isEmpty || _workerUrl.isEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final store = info.installerStore;
      final source = store == 'com.android.vending'
          ? 'Google Play'
          : (store == null || store.isEmpty ? 'manual install' : store);
      _appVersion = '${info.version}+${info.buildNumber} ($source)';

      if (Platform.isAndroid) {
        final di = await DeviceInfoPlugin().androidInfo;
        _deviceInfo =
            '${di.manufacturer} ${di.model}, Android ${di.version.release}';
      } else if (Platform.isIOS) {
        final di = await DeviceInfoPlugin().iosInfo;
        _deviceInfo = '${di.utsname.machine}, iOS ${di.systemVersion}';
      }
    } catch (_) {}
  }

  // Returns true if the report was successfully sent, false otherwise.
  Future<bool> report(Object error, StackTrace stack, {bool fatal = false}) async {
    if (_appSecret.isEmpty || _workerUrl.isEmpty) return false;

    // Deduplicate — skip if same error reported twice in a row.
    final stackStr = stack.toString();
    final hash = '${error.runtimeType}:${stackStr.substring(0, stackStr.length.clamp(0, 120))}';
    if (hash == _lastReportedHash) return false;
    _lastReportedHash = hash;

    final stackLines = stackStr
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(12)
        .join('\n');

    try {
      await _dio.post(
        _workerUrl,
        data: {
          'error': error.toString(),
          'stack': stackLines,
          'version': _appVersion ?? 'unknown',
          'device': _deviceInfo ?? 'unknown',
          'fatal': fatal,
          'breadcrumbs': _breadcrumbs.snapshot(),
        },
        options: Options(
          headers: {'X-App-Secret': _appSecret},
          contentType: Headers.jsonContentType,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
