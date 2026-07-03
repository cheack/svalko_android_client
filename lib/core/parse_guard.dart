import 'crash_reporter.dart';
import 'result.dart';

/// Runs [parse], reporting any thrown exception to [CrashReporter] and
/// turning it into [AppError.parseFailure] instead of letting it propagate.
/// Throw from inside [parse] to signal "markup didn't match expectations"
/// (e.g. an unexpectedly-null/empty parser result) — it gets reported too.
Result<T, AppError> guardParse<T>(T Function() parse) {
  try {
    return Ok(parse());
  } catch (e, st) {
    CrashReporter.instance.report(e, st);
    return const Err(AppError.parseFailure);
  }
}
