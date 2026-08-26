# MyAaptha Mobile

Flutter client for Android and iOS. The application shares MyAaptha's Spring Boot API and privacy rules with the web client.

## Available flows

- Sign in, sign up, token refresh, secure session restore, sign out
- Adaptive phone/tablet navigation using Material 3
- Relationship list with verified/privacy tags and profile photos
- People discovery and relationship creation
- Circles list, circle creation, members and group conversations
- Private one-to-one conversations with left/right message bubbles
- Personal, address, communication, education and employment profile fields
- Audio/video entry points and native camera/microphone permissions
- Android and iOS native project scaffolding

## Run locally

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_API_HOST:8080
```

Android Emulator automatically defaults to `http://10.0.2.2:8080`; iOS Simulator defaults to `http://localhost:8080`. Always provide `API_BASE_URL` for physical devices and cloud environments.

## Verification

```powershell
flutter analyze
flutter test test
flutter build apk --debug
```

Building iOS requires macOS with Xcode. Android builds require `ANDROID_HOME` or an Android SDK configured through Android Studio.

## Release configuration

- Use HTTPS for every non-local API endpoint.
- Inject the production API endpoint through `--dart-define` or CI.
- Configure Android signing in `android/key.properties` and the Gradle release block.
- Configure the Apple team, bundle identifier, signing and capabilities in Xcode.
- Keep user media in the backend's external/object storage; it is never packaged in the mobile app.
