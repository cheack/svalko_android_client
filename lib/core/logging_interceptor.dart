import 'package:dio/dio.dart';
import 'app_logger.dart';

class LoggingInterceptor extends Interceptor {
  static const _swKey = '_log_sw';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_swKey] = Stopwatch()..start();
    AppLogger.instance.info('→ ${_shortUrl(options.uri.toString())}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final sw = response.requestOptions.extra[_swKey] as Stopwatch?;
    sw?.stop();
    final ms = sw?.elapsedMilliseconds ?? -1;
    final url = _shortUrl(response.requestOptions.uri.toString());
    final fromCache = _isFromCache(response, ms);
    if (fromCache) {
      AppLogger.instance
          .cache('✓ cache ${ms}ms  $url', detail: _extraKeys(response));
    } else {
      AppLogger.instance.network(
        '↓ network ${ms}ms  $url',
        detail: '${response.statusCode}  ${_extraKeys(response)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sw = err.requestOptions.extra[_swKey] as Stopwatch?;
    sw?.stop();
    final ms = sw?.elapsedMilliseconds ?? -1;
    AppLogger.instance.error(
      '✗ ${err.type.name} ${ms}ms  ${_shortUrl(err.requestOptions.uri.toString())}',
      detail: err.message,
    );
    handler.next(err);
  }

  bool _isFromCache(Response response, int ms) {
    if (response.extra.keys.any((k) => k.toLowerCase().contains('cache'))) {
      return true;
    }
    if (response.headers.map.containsKey('age')) {
      return true;
    }
    if (ms >= 0 && ms < 30) {
      return true;
    }
    return false;
  }

  String _shortUrl(String url) {
    // Show path only to keep log lines short
    try {
      final uri = Uri.parse(url);
      return uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    } catch (_) {
      return url;
    }
  }

  String _extraKeys(Response response) {
    final keys = response.extra.keys.where((k) => k != '_log_sw').join(', ');
    return keys.isEmpty ? '' : 'extra: $keys';
  }
}
