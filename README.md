# Свалко

Неофициальный мобильный клиент для [svalko.org](https://svalko.org).

## Запуск

```sh
flutter run \
  --dart-define=BUILD_HASH=$(git rev-parse --short HEAD) \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

## Сборка APK

```sh
flutter build apk \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=BUILD_HASH=$(git rev-parse --short HEAD) \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

## Сборка App Bundle (Google Play)

```sh
flutter build appbundle \
  --build-number=$(git rev-list --count HEAD) \
  --dart-define=BUILD_HASH=$(git rev-parse --short HEAD) \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

AAB: `build/app/outputs/bundle/release/app-release.aab`

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
