sealed class Result<T, E> {
  const Result();
}

final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);
  final T value;
}

final class Err<T, E> extends Result<T, E> {
  const Err(this.error);
  final E error;
}

extension ResultX<T, E> on Result<T, E> {
  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T get valueOrThrow => switch (this) {
        Ok(:final value) => value,
        Err(:final error) => throw StateError('Result is Err: $error'),
      };

  T? get valueOrNull => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  Result<U, E> map<U>(U Function(T) f) => switch (this) {
        Ok(:final value) => Ok(f(value)),
        Err(:final error) => Err(error),
      };
}

enum AppError {
  network,
  timeout,
  parseFailure,
  notFound,
  unknown;

  @override
  String toString() => switch (this) {
        AppError.network => 'Ошибка сети',
        AppError.timeout => 'Превышено время ожидания',
        AppError.parseFailure => 'Ошибка разбора страницы',
        AppError.notFound => 'Страница не найдена',
        AppError.unknown => 'Неизвестная ошибка',
      };
}
