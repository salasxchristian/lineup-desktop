import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';
import 'updater.dart';
import 'xtream.dart';

/// LiveCategory filters that aren't provider categories.
const allCategory = '__all__';
const favoritesCategory = '__favorites__';

/// Everything the screens show: the login, the channel list, the guide cache and the one player.
///
/// Only one stream ever plays (most lines allow one or two connections), so the guide's preview
/// and the full-screen player share [player].
class AppState extends ChangeNotifier {
  AppState({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false)) {
    updater.addListener(notifyListeners);
  }

  final FlutterSecureStorage _storage;
  final updater = Updater();
  SharedPreferences? _prefs;
  static const _credentialsKey = 'xtream_credentials';

  // Login
  XtreamCredentials? credentials;
  XtreamClient? client;
  XtreamAccount? account;
  bool restoring = true;

  // Lists
  List<LiveCategory> categories = [];
  List<Channel> channels = [];
  Map<String, int> categoryCounts = {};
  bool loadingLists = false;
  String? listError;
  Set<int> favorites = {};
  String category = allCategory;
  String search = '';
  int? selectedId;

  // Look
  ThemeId themeId = ThemeId.dark;
  Palette get palette => Palette.of(themeId);

  // Guide: `get_short_epg` per channel, fetched as rows come on screen.
  final Map<int, List<Programme>> epg = {};
  final Map<int, DateTime> _epgFetched = {};
  final Set<int> _epgPending = {};
  final List<int> _epgQueue = [];
  int _epgRunning = 0;
  static const _epgConcurrency = 4;
  static const _epgLifetime = Duration(minutes: 15);

  // Playback
  late final Player player = Player(configuration: const PlayerConfiguration(title: 'Lineup', bufferSize: 32 * 1024 * 1024));
  late final VideoController video = VideoController(player);
  int? playingId;
  Timer? _previewDebounce;

  // Mini player: the main window shrunk to a small video that stays above other windows.
  bool mini = false;
  Rect? _fullBounds;

  Future<void> restore() async {
    _prefs = await SharedPreferences.getInstance();
    themeId = ThemeId.values.asNameMap()[_prefs!.getString('theme')] ?? ThemeId.dark;
    favorites = (_prefs!.getStringList('favorites') ?? []).map(int.tryParse).whereType<int>().toSet();
    category = _prefs!.getString('category') ?? allCategory;
    selectedId = _prefs!.getInt('selected');
    if (player.platform is NativePlayer) {
      final native = player.platform as NativePlayer;
      await native.setProperty('user-agent', XtreamClient.userAgent);
      await native.setProperty('network-timeout', '15');
    }
    try {
      final raw = await _storage.read(key: _credentialsKey);
      final saved = raw == null ? null : XtreamCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (saved != null) {
        credentials = saved;
        client = XtreamClient(saved);
        unawaited(_loadLists());
        unawaited(client!.account().then((a) {
          account = a;
          notifyListeners();
        }, onError: (_) {}));
      }
    } catch (_) {
      // Unreadable keychain entry: start at Connect.
    }
    restoring = false;
    notifyListeners();
    unawaited(updater.start());
  }

  /// Checks the login, saves it to the keychain and loads the channels. Throws [XtreamException].
  Future<void> connect(XtreamCredentials creds) async {
    final c = XtreamClient(creds);
    account = await c.account();
    client?.close();
    client = c;
    credentials = creds;
    await _storage.write(key: _credentialsKey, value: jsonEncode(creds.toJson()));
    epg.clear();
    _epgFetched.clear();
    notifyListeners();
    await _loadLists();
  }

  Future<void> signOut() async {
    await exitMini();
    await player.stop();
    playingId = null;
    await _storage.delete(key: _credentialsKey);
    client?.close();
    client = null;
    credentials = null;
    account = null;
    channels = [];
    categories = [];
    epg.clear();
    _epgFetched.clear();
    notifyListeners();
  }

  Future<void> reload() => _loadLists();

  Future<void> _loadLists() async {
    final c = client;
    if (c == null) return;
    loadingLists = true;
    listError = null;
    notifyListeners();
    try {
      final results = await Future.wait([c.liveCategories(), c.liveStreams()]);
      categories = results[0] as List<LiveCategory>;
      channels = (results[1] as List<Channel>)..sort(_byNumber);
      // Drop a tag every name shares ("US| ") so names fit the sidebar and guide.
      final tag = sharedTag(categories.map((c) => c.name));
      if (tag != null) {
        categories = [for (final c in categories) LiveCategory(id: c.id, name: stripTag(c.name, tag))];
        channels = [
          for (final ch in channels)
            Channel(id: ch.id, name: stripTag(ch.name, tag), number: ch.number, icon: ch.icon, categoryIds: ch.categoryIds),
        ];
      }
      categoryCounts = {};
      for (final ch in channels) {
        for (final id in ch.categoryIds) {
          categoryCounts[id] = (categoryCounts[id] ?? 0) + 1;
        }
      }
      categories = categories.where((cat) => categoryCounts.containsKey(cat.id)).toList();
      if (category != allCategory && category != favoritesCategory && !categories.any((x) => x.id == category)) {
        category = allCategory;
      }
      final visible = visibleChannels;
      if (visible.isNotEmpty && !visible.any((ch) => ch.id == selectedId)) selectedId = visible.first.id;
      if (selectedId != null) _schedulePreview(selectedId!, immediately: true);
    } on XtreamException catch (e) {
      listError = e.message;
    } finally {
      loadingLists = false;
      notifyListeners();
    }
  }

  static int _byNumber(Channel a, Channel b) {
    final na = double.tryParse(a.number ?? ''), nb = double.tryParse(b.number ?? '');
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    if (na != null && nb == null) return -1;
    if (na == null && nb != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  // MARK: Filtering and selection

  List<Channel> get visibleChannels {
    Iterable<Channel> list = channels;
    if (category == favoritesCategory) {
      list = list.where((ch) => favorites.contains(ch.id));
    } else if (category != allCategory) {
      list = list.where((ch) => ch.categoryIds.contains(category));
    }
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((ch) => ch.name.toLowerCase().contains(q) || (ch.number ?? '') == q);
    }
    return list.toList();
  }

  Channel? get selected {
    for (final ch in channels) {
      if (ch.id == selectedId) return ch;
    }
    return null;
  }

  Channel? channelById(int? id) {
    for (final ch in channels) {
      if (ch.id == id) return ch;
    }
    return null;
  }

  int countFor(String id) {
    if (id == allCategory) return channels.length;
    if (id == favoritesCategory) return channels.where((ch) => favorites.contains(ch.id)).length;
    return categoryCounts[id] ?? 0;
  }

  String categoryName(String id) {
    if (id == allCategory) return 'All';
    if (id == favoritesCategory) return 'Favorites';
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  /// The category used for a channel's logo color and tag.
  String primaryCategoryName(Channel ch) => ch.categoryIds.isEmpty ? '' : categoryName(ch.categoryIds.first);

  void setCategory(String id) {
    category = id;
    _prefs?.setString('category', id);
    notifyListeners();
  }

  void setSearch(String q) {
    search = q;
    notifyListeners();
  }

  /// Selects a channel in the guide; the preview follows after a short pause so arrowing through
  /// the list doesn't open a stream per row.
  void select(int id) {
    if (selectedId == id) return;
    selectedId = id;
    _prefs?.setInt('selected', id);
    _schedulePreview(id);
    notifyListeners();
  }

  /// Moves the selection up or down the visible list. Returns the new index.
  int? step(int delta, {bool playNow = false}) {
    final list = visibleChannels;
    if (list.isEmpty) return null;
    var i = list.indexWhere((ch) => ch.id == selectedId);
    i = i < 0 ? 0 : (i + delta).clamp(0, list.length - 1);
    final id = list[i].id;
    if (playNow) {
      selectedId = id;
      _prefs?.setInt('selected', id);
      play(id);
      notifyListeners();
    } else {
      select(id);
    }
    return i;
  }

  void toggleFavorite(int id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _prefs?.setStringList('favorites', favorites.map((e) => '$e').toList());
    notifyListeners();
  }

  void setTheme(ThemeId id) {
    themeId = id;
    _prefs?.setString('theme', id.name);
    notifyListeners();
  }

  // MARK: Playback

  void _schedulePreview(int id, {bool immediately = false}) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(immediately ? Duration.zero : const Duration(milliseconds: 450), () => play(id));
  }

  Future<void> play(int id) async {
    final c = client;
    if (c == null) return;
    _previewDebounce?.cancel();
    if (playingId != id) {
      playingId = id;
      notifyListeners();
      await player.open(Media(c.liveUrl(id)));
    }
    await player.setVolume(100);
  }

  /// Full screen: plays the selected channel.
  Future<void> watch() async {
    final id = selectedId;
    if (id == null) return;
    await play(id);
  }

  /// Back to the guide: the preview keeps playing, with sound even if it was muted in the player.
  Future<void> leavePlayer() async {
    await player.setVolume(100);
    notifyListeners();
  }

  // MARK: Mini player

  static const _miniSize = Size(416, 234);
  static const fullMinimumSize = Size(960, 640);

  /// Shrinks the window to a 16:9 mini player at its top right corner and keeps it on top.
  Future<void> enterMini() async {
    if (mini) return;
    final id = playingId ?? selectedId;
    if (id == null) return;
    if (playingId == null) await play(id);
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      // macOS animates out of full screen; resizing during it is ignored.
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    _fullBounds = await windowManager.getBounds();
    mini = true;
    notifyListeners();
    final b = _fullBounds!;
    if (Platform.isMacOS) {
      // A hidden title bar still takes clicks along the top and zooms on double-click; frameless hides it for real.
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(true);
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    }
    await windowManager.setMinimumSize(const Size(256, 144));
    // Caps a zoom too: macOS still zooms on a double-click along the top edge.
    await windowManager.setMaximumSize(const Size(960, 540));
    await windowManager.setBounds(Rect.fromLTWH(b.right - _miniSize.width - 24, b.top + 24, _miniSize.width, _miniSize.height));
    await windowManager.setAspectRatio(16 / 9);
    await windowManager.setAlwaysOnTop(true);
  }

  /// Back to the full window where it was.
  Future<void> exitMini() async {
    if (!mini) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAspectRatio(0);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBackgroundColor(const Color(0xFF0B0C0E));
    await windowManager.setMinimumSize(fullMinimumSize);
    // No limit: macOS takes a huge size, Windows takes -1.
    await windowManager.setMaximumSize(Platform.isMacOS ? const Size(100000, 100000) : const Size(-1, -1));
    if (_fullBounds != null) await windowManager.setBounds(_fullBounds!);
    mini = false;
    notifyListeners();
  }

  // MARK: Guide

  /// Asks for a channel's programmes if they're missing or old. Cheap to call on every build.
  void ensureEpg(int id) {
    final fetched = _epgFetched[id];
    if (_epgPending.contains(id)) return;
    if (fetched != null && DateTime.now().difference(fetched) < _epgLifetime) return;
    _epgPending.add(id);
    _epgQueue.add(id);
    _pumpEpg();
  }

  void _pumpEpg() {
    while (_epgRunning < _epgConcurrency && _epgQueue.isNotEmpty) {
      final id = _epgQueue.removeLast(); // newest first: what's on screen now
      _epgRunning++;
      _fetchEpg(id).whenComplete(() {
        _epgRunning--;
        _epgPending.remove(id);
        _pumpEpg();
      });
    }
  }

  Future<void> _fetchEpg(int id) async {
    final c = client;
    if (c == null) return;
    try {
      epg[id] = await c.shortEpg(id);
    } catch (_) {
      epg[id] = const [];
    }
    _epgFetched[id] = DateTime.now();
    notifyListeners();
  }

  bool epgLoaded(int id) => _epgFetched.containsKey(id);

  /// The programme on now and the one after it.
  (Programme?, Programme?) nowNext(int id, DateTime now) {
    final list = epg[id] ?? const [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].isLive(now)) return (list[i], i + 1 < list.length ? list[i + 1] : null);
    }
    for (final p in list) {
      if (p.start.isAfter(now)) return (null, p);
    }
    return (null, null);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    player.dispose();
    client?.close();
    super.dispose();
  }
}
