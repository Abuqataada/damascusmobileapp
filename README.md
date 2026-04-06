# Damascus Projects WebView Wrapper

A Flutter wrapper for `https://app.damascusprojects.com` with support for:

- File uploads
- Photo capture
- Video recording
- Video-call permissions through WebRTC
- External-link handling
- WebView back navigation and refresh controls

## Setup

1. Run `flutter pub get`
2. Run the app with `flutter run`

## Notes

- Android permissions for camera, microphone, storage, and internet are configured.
- iOS privacy strings for camera, microphone, and photo library access are configured.
- External links and non-web schemes open in the device browser or native app.
- Firebase push notifications require your Firebase project files:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`

## Firebase Push Setup

See [docs/firebase_push_setup.md](docs/firebase_push_setup.md) for the exact Firebase steps and a safe FCM payload format that works with this app without changing the WebView behavior.

## Splash Screen And App Icon

See [docs/splash_icon_setup.md](docs/splash_icon_setup.md) for the image paths and generation commands.

## Live Recording Save Bridge

See [docs/recording_save_bridge.md](docs/recording_save_bridge.md) for the WebView-safe way to save live stream recordings on mobile devices.
