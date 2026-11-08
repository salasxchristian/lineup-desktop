# lineup-desktop

**Lineup** for Mac and Windows: a simple live TV client for any Xtream Codes line (Dispatcharr included). Live TV only, no movies or series. Flutter, with playback through media_kit (libmpv), so MPEG-TS, HLS, AC3 and HEVC all play.

Design: [Live TV Client canvas](https://claude.ai/artifact/MmSkrfVrv3wpJR4CF18vdA) (Guide, Player, Connect, Appearance, in Dark, Lilac and Pastel blue).

## Screens

- **Connect**: server URL, username, password. The login is saved in the system keychain.
- **Guide**: a left sidebar with search, categories (with counts) and Settings. Next to it, the selected channel with a muted live preview and what's on, then a two-hour timeline with a now line. The guide comes from `get_short_epg`, fetched as rows come on screen (four at a time, kept 15 minutes).
- **Player**: the video with a panel that fades after 4 s.
- **Settings**: theme picker (Dark, Lilac, Pastel blue) and the provider's status, Refresh channels and Sign out.

Only one stream plays at a time: the preview and the player share it, so a one-connection line works.

## Keys

| Where | Key | Does |
|---|---|---|
| Guide | ↑ ↓, Page Up/Down | move through channels |
| Guide | ← → | previous / next category |
| Guide | Return | watch the selected channel |
| Guide | / | search |
| Player | ↑ ↓ | change channel |
| Player | F, double-click | full screen |
| Player | M | mute |
| Player | Esc | back to the guide |

## Run

```bash
flutter run -d macos
```

Windows builds have to run on a Windows machine (`flutter build windows`).

### Without a provider

`tool/fake_xtream.dart` is a pretend panel on `127.0.0.1:8190` (login `demo` / `demo`) with 15 channels, a guide around the current time, and one test video for every channel:

```bash
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440 -t 120 -c:v libx264 -pix_fmt yuv420p -c:a aac -f mpegts tool/test.ts
dart run tool/fake_xtream.dart
```

## Code

- `lib/xtream.dart`: `player_api.php` client and lenient models
- `lib/state.dart`: login, channels, favorites, guide cache, the one player
- `lib/guide_layout.dart`: timeline math (tested)
- `lib/theme.dart`: the three palettes
- `lib/screens/`: Connect, Guide, Player, Settings (`appearance.dart`)
- `tool/make_icon.py`: draws the app icon (macOS AppIcon set and Windows `.ico`) from the canvas's 1024 grid

```bash
flutter analyze && flutter test
```

## Release

Push a version tag and GitHub Actions (`.github/workflows/release.yml`) builds everything and publishes a GitHub Release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

| File | What |
|---|---|
| `LineupSetup-<version>.exe` | Windows installer (Inno Setup, `windows/installer.iss`); installs per user, no admin |
| `Lineup-<version>-windows-x64.zip` | the same app, portable: unzip and run `Lineup.exe` |
| `Lineup-<version>-macos.zip` | `Lineup.app` |

Running the workflow by hand (Actions > Release > Run workflow) builds the same files as artifacts without a release.

Builds aren't code signed: Windows SmartScreen asks once (More info > Run anyway), and macOS needs right-click > Open the first time.
