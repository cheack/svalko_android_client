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
