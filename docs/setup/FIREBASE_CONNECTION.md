# Firebase connection status

Firebase project: `forum-d8b06`

## Connected platforms

- Android: package `com.qrscanning.hrms`
- Web: Firebase app `qr_scanning (web)`

The application initializes these platforms from `lib/firebase_options.dart`.

## Deferred platforms

- iOS
- macOS
- Windows

These Firebase apps are registered, but their complete SDK configuration is not yet stored in Dart. Keep them deferred until their SDK configuration has been verified.

## FlutterFire CLI compatibility note

`flutterfire configure` 1.4.1 fails in this project while attempting to open `android/app/build.gradle`; the Android app module uses `android/app/build.gradle.kts`. Android and Web configuration was therefore populated from verified `firebase apps:sdkconfig` output instead of fabricating a second Gradle file.

Do not create an empty `android/app/build.gradle` alongside `build.gradle.kts` as a workaround.
