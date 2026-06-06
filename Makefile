.PHONY: verify doctor compose-verify android-build ios-build docker-up docker-build-app backend-test flutter-test clean

verify:
	bash ./tools/verify-all.sh

doctor:
	bash ./tools/doctor-environment.sh

compose-verify:
	bash ./tools/verify-compose-stack.sh

android-build:
	cd app/android && JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home PATH="/opt/homebrew/opt/openjdk@17/bin:$$PATH" ./gradlew assembleDebug
	test -s app/build/app/outputs/flutter-apk/app-debug.apk

ios-build:
	bash ./tools/verify-ios-build.sh

docker-up:
	bash ./tools/docker-up.sh

docker-build-app:
	./tools/prepare-docker-backend.sh >/tmp/xiguang-target-arch
	DOCKER_TARGETARCH="$$(cat /tmp/xiguang-target-arch)" docker compose build app

backend-test:
	cd backend && go test ./...

flutter-test:
	cd app && /Users/jinzihan/.cache/codex-flutter-sdk/bin/dart analyze . && /Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter test

clean:
	rm -rf app/build app/android/build backend/bin
