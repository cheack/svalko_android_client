import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _workerUrl = String.fromEnvironment('CRASH_WORKER_URL');
const _appSecret = String.fromEnvironment('APP_SECRET');

class CrashReporter {
  CrashReporter._();

  static final instance = CrashReporter._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  String? _appVersion;
  String? _deviceInfo;
  String? _lastReportedHash;

  Future<void> init() async {
    if (_appSecret.isEmpty || _workerUrl.isEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';

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
  Future<bool> report(Object error, StackTrace stack) async {
    if (_appSecret.isEmpty || _workerUrl.isEmpty) return false;

    // Deduplicate — skip if same error reported twice in a row.
    final hash = '${error.runtimeType}:${stack.toString().substring(0, 120)}';
    if (hash == _lastReportedHash) return false;
    _lastReportedHash = hash;

    final stackLines = stack
        .toString()
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
