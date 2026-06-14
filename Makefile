SECRETS      := $(shell python3 -c "import json; d=json.load(open('secrets.json')); print(' '.join(f'--dart-define={k}={v}' for k,v in d.items()))" 2>/dev/null)
DEFINES      := $(SECRETS) --dart-define=BUILD_HASH=$(shell git rev-parse --short HEAD) --dart-define=BUILD_DATE=$(shell date +%Y-%m-%d)
BUILD_NAME   := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
BUILD_NUMBER := $(shell git rev-list --count HEAD)

run:
	flutter run $(DEFINES)

bundle:
	@echo "build-name:   $(BUILD_NAME)"
	@echo "build-number: $(BUILD_NUMBER)"
	@read -p "Продолжить? [y/N] " ans && [ "$$ans" = "y" ]
	flutter build appbundle $(DEFINES) \
		--build-name=$(BUILD_NAME) \
		--build-number=$(BUILD_NUMBER)

apk:
	@echo "build-name:   $(BUILD_NAME)"
	@echo "build-number: $(BUILD_NUMBER)"
	@echo "1) arm64-v8a   2) armeabi-v7a   3) x86_64   4) universal"
	@read -p "Выбор (можно несколько, например 1 3): " choices; \
	read -p "Продолжить? [y/N] " ans && [ "$$ans" = "y" ]; \
	for c in $$choices; do \
		case "$$c" in \
			1) flutter build apk --release --target-platform android-arm64 $(DEFINES) \
				--build-name=$(BUILD_NAME) --build-number=$(BUILD_NUMBER) ;; \
			2) flutter build apk --release --target-platform android-arm $(DEFINES) \
				--build-name=$(BUILD_NAME) --build-number=$(BUILD_NUMBER) ;; \
			3) flutter build apk --release --target-platform android-x64 $(DEFINES) \
				--build-name=$(BUILD_NAME) --build-number=$(BUILD_NUMBER) ;; \
			4) flutter build apk --release $(DEFINES) \
				--build-name=$(BUILD_NAME) --build-number=$(BUILD_NUMBER) ;; \
		esac; \
	done
