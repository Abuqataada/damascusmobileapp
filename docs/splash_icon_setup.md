# Splash Screen And App Icon

This project is now configured to generate both the splash screen and app icon from your own images.

## Expected asset paths

Place your images here:

- `assets/app/splash.png`
- `assets/app/icon.png`
- `assets/app/icon_foreground.png`

## What each image is for

- `splash.png`: the startup splash screen image
- `icon.png`: the main app icon source
- `icon_foreground.png`: the foreground layer for Android adaptive icons

## Generate the assets

After adding your images, run:

```powershell
flutter pub get
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

## Notes

- Use a square PNG for the icon, ideally 1024x1024.
- Use a transparent PNG for `icon_foreground.png` if you want Android adaptive icon layering.
- `flutter_native_splash` is configured to use a white splash background for a cleaner startup screen.
