# Pretty Saver

Android app (Flutter) that saves public Instagram reels to the phone's gallery in the best available quality, with audio.

- Paste a reel link, or share a reel from Instagram straight to the app
- Saves to `Download/PrettySaver` (visible in the gallery)
- Download history with play, share and delete
- English, हिंदी and मराठी; light/dark theme, font and text size options
- No server: downloads run on the phone through [yt-dlp](https://github.com/yt-dlp/yt-dlp) via [youtubedl-android](https://github.com/JunkFood02/youtubedl-android), which updates itself daily

## User guide

Install and usage steps with screenshots: [docs/Pretty-Saver-Guide.pdf](docs/Pretty-Saver-Guide.pdf)

## Build

```
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
```

The APK is written to `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Project layout

- `android/app/src/main/kotlin/.../MainActivity.kt`: bridge to yt-dlp, saving to Downloads, share intent
- `android/app/src/main/kotlin/.../LoginActivity.kt`: optional Instagram sign-in when Instagram refuses logged-out requests
- `lib/core/`: engine channel, link parsing, error classification
- `lib/state/`: Riverpod state for downloads, history, settings
- `lib/ui/`: screens
- `lib/l10n/strings.dart`: all text in English, Hindi and Marathi

For personal use. Videos belong to their creators.

Made with ♥ by Priti
