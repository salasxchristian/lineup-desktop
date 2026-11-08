# Notes

- Flutter 3.47.9 from Homebrew (`brew install --cask flutter`), CocoaPods from Homebrew. media_kit's macOS plugins don't support Swift Package Manager yet, so pods are still needed.
- `window_manager` is pinned to 0.5.x: 0.6 moved the old `windowManager` API to `legacy.dart` on top of nativeapi. `google_fonts` is pinned to 6.x (9.x didn't type-check against this Flutter).
- Going full screen in the same moment the player route opens crashed Impeller (`impeller::Canvas::SetupRenderPass`, null render target). So the player opens windowed and F / double-click toggles full screen; that path doesn't crash.
- Keychain: `flutter_secure_storage` with `usesDataProtectionKeychain: false`, which works unsigned. Every debug rebuild has a new ad-hoc signature, so macOS asks again for keychain access (Always Allow). A signed release won't.
- Sandbox: `com.apple.security.network.client` is added to both entitlement files; mpv/ffmpeg and Dart sockets don't go through ATS, so plain `http://` panels work.
- Providers that tag names ("US| LOCALS") get the dominant tag dropped for display (`sharedTag` in `xtream.dart`); other tags stay.
- Background clicks and typing from computer use don't reach Flutter's text fields; typing needs full-screen control.
- Works against the real Dispatcharr line (my own panel, hundreds of channels): `get_short_epg` returns guide data and logos load.
- Updater (`lib/updater.dart`): reads `releases/latest` from the public repo. Windows downloads the installer and runs it with `/VERYSILENT`; the installer's `skipifnotsilent` run entry reopens Lineup. The Mac app stays sandboxed (a deliberate choice), so it can't replace its own bundle and opens the zip download in the browser instead.
- Reconnect (`AppState` > Reconnect): mpv's `stream-lavf-o` reconnect options handle short drops inside ffmpeg; the app watches `error`, `completed` (a live stream never really ends) and buffering longer than 12 s. Retries reset after 10 s of clean playback. Not yet tested against a real drop.
