# Local Development

This page documents the local Flutter setup for the Family Clan App repository.

## App location

The local Flutter application scaffold lives at:

```text
mobile/flutter_app/
```

## Installed toolchain

On this machine, the following components were installed:

- Flutter SDK
- Android SDK command-line tools
- Android platform packages and emulator
- CocoaPods

## Environment variables

The shell configuration exports:

- `JAVA_HOME`
- `ANDROID_SDK_ROOT`
- `ANDROID_HOME`
- Flutter and Android SDK paths in `PATH`

Open a new terminal or run `source ~/.zshrc` after setup changes.

## Verification

Run:

```bash
./scripts/flutter_doctor_local.sh
```

Expected result:

- Android toolchain passes
- Flutter SDK passes
- CocoaPods is detected
- iOS remains blocked until full Xcode is installed

## Start Android emulator

Run:

```bash
./scripts/run_android_emulator.sh
```

The configured emulator name is:

```text
flutter_android_test
```

## Run the app

```bash
cd mobile/flutter_app
flutter run
```

## iOS requirement

iOS simulator and device builds require the full Xcode application.

After installing Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
cd mobile/flutter_app
pod install --project-directory=ios
flutter run -d ios
```
