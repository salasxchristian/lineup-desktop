import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// A published GitHub release of Lineup.
class Release {
  Release({required this.version, required this.notes, required this.page, required this.assets});
  final String version;
  final String notes;
  final Uri page;
  final Map<String, Uri> assets;

  static Release? fromJson(Map<String, dynamic> j) {
    final tag = j['tag_name'];
    final page = Uri.tryParse(j['html_url'] as String? ?? '');
    if (tag is! String || page == null) return null;
    return Release(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      // GitHub's notes are markdown; drop the bold and heading marks so they read as plain text.
      notes: (j['body'] as String? ?? '').replaceAll(RegExp(r'\*\*|__'), '').replaceAll(RegExp(r'^#+\s*', multiLine: true), '').trim(),
      page: page,
      assets: {
        for (final a in (j['assets'] as List? ?? const []).whereType<Map<String, dynamic>>())
          if (a['name'] is String && Uri.tryParse(a['browser_download_url'] as String? ?? '') != null)
            a['name'] as String: Uri.parse(a['browser_download_url'] as String),
      },
    );
  }

  /// The file this platform installs from: the Windows installer or the zipped Mac app.
  Uri? get download => assets[Platform.isWindows ? 'LineupSetup-$version.exe' : 'Lineup-$version-macos.zip'];
}

/// True when [a] is a later version than [b]. Compares the dotted numbers and ignores a `+build` or `-pre` suffix.
bool isNewer(String a, String b) {
  List<int> parts(String v) => v.split(RegExp(r'[+-]')).first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}

enum UpdateStatus { idle, checking, upToDate, available, downloading, installing, failed }

/// Checks GitHub for a newer release. Windows installs it in the app with the silent installer; the sandboxed Mac app
/// can't replace itself, so it downloads the zip through the browser.
class Updater extends ChangeNotifier {
  Updater({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const repo = 'salasxchristian/lineup-desktop';
  static final releasesPage = Uri.parse('https://github.com/$repo/releases');
  static const _checkEvery = Duration(hours: 12);

  final http.Client _http;
  UpdateStatus status = UpdateStatus.idle;
  String current = '';
  Release? latest;
  double? progress;
  String? error;
  Timer? _timer;

  static bool get installsInApp => Platform.isWindows;

  bool get busy => status == UpdateStatus.checking || status == UpdateStatus.downloading || status == UpdateStatus.installing;

  /// Reads this build's version and checks now, then every 12 hours.
  Future<void> start() async {
    current = (await PackageInfo.fromPlatform()).version;
    _timer = Timer.periodic(_checkEvery, (_) => check(quiet: true));
    await check(quiet: true);
  }

  /// Asks GitHub for the latest release. Quiet checks don't show errors; they just stay idle.
  Future<void> check({bool quiet = false}) async {
    if (busy) return;
    _set(UpdateStatus.checking);
    try {
      final res = await _http
          .get(Uri.parse('https://api.github.com/repos/$repo/releases/latest'), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw HttpException('GitHub answered ${res.statusCode}');
      latest = Release.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      final newer = latest != null && isNewer(latest!.version, current);
      _set(newer ? UpdateStatus.available : UpdateStatus.upToDate);
    } catch (e) {
      error = 'Couldn’t check for updates.';
      _set(quiet ? UpdateStatus.idle : UpdateStatus.failed);
    }
  }

  /// Windows: downloads the installer, starts it and quits so it can replace this app. macOS: opens the download.
  Future<void> install() async {
    final release = latest;
    final url = release?.download;
    if (release == null || busy) return;
    if (url == null || !installsInApp) {
      await _openUrl(url ?? release.page);
      return;
    }
    try {
      final dir = await Directory.systemTemp.createTemp('lineup-update-');
      final file = File('${dir.path}/${url.pathSegments.last}');
      await _download(url, file);
      _set(UpdateStatus.installing);
      // The installer closes Lineup if it's still open, installs over it and starts the new version.
      await Process.start(file.path, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached);
      exit(0);
    } catch (e) {
      error = e is _UpdateException ? e.message : 'The update didn’t install. You can download it from GitHub instead.';
      _set(UpdateStatus.failed);
    }
  }

  Future<void> _download(Uri url, File to) async {
    progress = 0;
    _set(UpdateStatus.downloading);
    final res = await _http.send(http.Request('GET', url));
    if (res.statusCode != 200) throw _UpdateException('The download failed (${res.statusCode}).');
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = to.openWrite();
    await for (final chunk in res.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        progress = received / total;
        notifyListeners();
      }
    }
    await sink.close();
  }

  Future<void> openReleasePage() => _openUrl(latest?.page ?? releasesPage);

  Future<void> _openUrl(Uri uri) async {
    final url = uri.toString();
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else {
      await Process.run('open', [url]);
    }
  }

  void _set(UpdateStatus s) {
    status = s;
    if (s != UpdateStatus.failed) error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _UpdateException implements Exception {
  _UpdateException(this.message);
  final String message;
}
