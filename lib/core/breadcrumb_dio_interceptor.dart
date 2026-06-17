import 'package:dio/dio.dart';
import 'breadcrumb_collector.dart';

class BreadcrumbDioInterceptor extends Interceptor {
  BreadcrumbDioInterceptor(this._collector);

  final BreadcrumbCollector _collector;

  static const _startTimeKey = '_breadcrumb_start_ms';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, statusCode: response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, statusCode: err.response?.statusCode, isError: true);
    handler.next(err);
  }

  void _record(RequestOptions options, {int? statusCode, bool isError = false}) {
    final startMs = options.extra[_startTimeKey] as int?;
    final durationMs = startMs != null
        ? DateTime.now().millisecondsSinceEpoch - startMs
        : null;
    _collector.addHttp(
      options.method,
      options.uri.toString(),
      statusCode: statusCode,
      durationMs: durationMs,
      isError: isError,
    );
  }
}
