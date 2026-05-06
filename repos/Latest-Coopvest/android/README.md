# Android Build Configuration

## Overview
This directory contains the Android-specific configuration for the CoopVest mobile application built with Flutter.

## Build Requirements
- Android SDK 34 (API level 34)
- Android NDK 25.2.9519653
- Gradle 8.1.0
- Kotlin 1.9.0
- Java 8 or higher

## Configuration Files

### local.properties
This file contains local machine-specific settings and is NOT committed to version control.

**To set up your local environment:**
1. Copy `local.properties.template` to `local.properties`
2. Update the paths to match your system:
   ```properties
   sdk.dir=/path/to/android-sdk
   flutter.sdk=/path/to/flutter
   ```

### gradle.properties
Contains global Gradle configuration settings:
- JVM memory settings
- AndroidX compatibility flags
- SDK version specifications
- NDK version

### build.gradle (root)
Root-level Gradle configuration with:
- Kotlin version specification
- Google Services plugin
- Repository configuration

### app/build.gradle
Application-level Gradle configuration with:
- Android SDK and NDK versions
- Compilation options
- Firebase dependencies
- Flutter integration

## Building the App

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

### Clean Build
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build apk
```

## Troubleshooting

### "Unsupported Gradle project" Error
This error occurs when the Gradle configuration is incompatible with Flutter. Solutions:
1. Ensure `local.properties` exists with correct SDK paths
2. Verify `gradle.properties` has correct settings
3. Check that `app/build.gradle` includes `apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"`
4. Run `flutter clean` and rebuild

### Gradle Sync Issues
1. Invalidate caches: `./gradlew --stop`
2. Clean: `./gradlew clean`
3. Rebuild: `flutter pub get && flutter build apk`

### Kotlin Compilation Errors
If you see errors like "Unresolved reference: filePermissions, user, read, write":
1. Ensure Kotlin version is 1.9.24 or higher (check `android/build.gradle`)
2. Verify `gradle.properties` has `kotlin.jvm.target=1.8`
3. Run `flutter clean` and rebuild
4. If persists, try: `cd android && ./gradlew clean && cd ..`

### Firebase Configuration
Ensure `google-services.json` is present in `app/` directory with correct Firebase project configuration.

## Dependencies
- Firebase (messaging, auth, firestore, storage, analytics, crashlytics)
- AndroidX libraries
- Kotlin standard library

## References
- [Flutter Android Setup](https://flutter.dev/docs/get-started/install/macos#android-setup)
- [Gradle Documentation](https://gradle.org/releases/)
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)