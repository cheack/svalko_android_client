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
	@read -p "Продолжить? [y/N] " ans && [ "$$ans" = "y" ]
	flutter build apk --release --split-per-abi $(DEFINES) \
		--build-name=$(BUILD_NAME) \
		--build-number=$(BUILD_NUMBER)
	flutter build apk --release $(DEFINES) \
		--build-name=$(BUILD_NAME) \
		--build-number=$(BUILD_NUMBER)
