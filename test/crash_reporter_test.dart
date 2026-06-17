import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/crash_reporter.dart';

Dio _fakeDio({bool fail = false}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (fail) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ));
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      }
    },
  ));
  return dio;
}

void main() {
  group('CrashReporter.report', () {
    test('returns true on successful post', () async {
      final reporter = CrashReporter.test(dio: _fakeDio());
      final result = await reporter.report(Exception('boom'), StackTrace.current);
      expect(result, isTrue);
    });

    test('returns false when network fails', () async {
      final reporter = CrashReporter.test(dio: _fakeDio(fail: true));
      final result = await reporter.report(Exception('boom'), StackTrace.current);
      expect(result, isFalse);
    });

    test('deduplicates consecutive identical errors', () async {
      final reporter = CrashReporter.test(dio: _fakeDio());
      final stack = StackTrace.current;
      final error = Exception('boom');
      final first = await reporter.report(error, stack);
      final second = await reporter.report(error, stack);
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('sends again after a different error type', () async {
      final reporter = CrashReporter.test(dio: _fakeDio());
      final stack = StackTrace.current;
      await reporter.report(Exception('e'), stack);
      final result = await reporter.report(StateError('e'), stack);
      expect(result, isTrue);
    });

    test('does not crash on a stack trace shorter than 120 characters', () async {
      final reporter = CrashReporter.test(dio: _fakeDio());
      final shortStack = StackTrace.fromString('#0 main (main.dart:1)');
      expect(
        () => reporter.report(Exception('short'), shortStack),
        returnsNormally,
      );
    });
  });
}
