# Свалко

Неофициальный мобильный клиент для [svalko.org](https://svalko.org).

## Настройка секретов

Скопируй `secrets.json.example` → `secrets.json` и заполни значения:

```json
{
  "APP_SECRET": "...",
  "CRASH_HANDLER_URL": "https://your-worker.workers.dev"
}
```

`secrets.json` не коммитится. Без него приложение работает, но краш-репортер отключён.

## Запуск и сборка

```sh
make run     # flutter run с подстановкой секретов
make bundle  # flutter build appbundle (Google Play)
make apk     # flutter build apk (предложит выбрать ABI)
```

Версия берётся из последнего git-тега: `git tag 1.2.7 && make bundle`.

- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Подпись релиза

Создайте `android/key.properties` (не коммитить):

```properties
storePassword=...
keyPassword=...
keyAlias=svalko
storeFile=svalko.keystore
```

Keystore генерируется один раз:

```sh
keytool -genkey -v \
  -keystore android/app/svalko.keystore \
  -alias svalko \
  -keyalg RSA -keysize 2048 -validity 10000
```

## Краш-репортер

При необработанном исключении приложение отправляет `POST` на `CRASH_HANDLER_URL`.

Заголовок:

```
X-App-Secret: <APP_SECRET>
Content-Type: application/json
```

Тело:

```json
{
  "error": "StateError: bad state",
  "stack": "#0  ...\n#1  ...",
  "version": "1.2.7+312",
  "device": "Google Pixel 7, Android 14",
  "fatal": false
}
```

`stack` — первые 12 непустых строк стектрейса. Повторная отправка одной и той же ошибки дедуплицируется (отправляется только один раз подряд).

`fatal: true` — ошибка поймана в `PlatformDispatcher.onError` или `runZonedGuarded`; без обработчика приложение бы упало. `fatal: false` — ошибка поймана в `FlutterError.onError` или блоке `try/catch`; приложение продолжало работать.
