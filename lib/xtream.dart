import 'dart:convert';

import 'package:http/http.dart' as http;

/// An Xtream Codes login: the panel's address plus a line's username and password.
class XtreamCredentials {
  XtreamCredentials({required String server, required this.username, required this.password})
      : server = normalizeServer(server);

  final String server;
  final String username;
  final String password;

  /// `example.com:8080/` -> `http://example.com:8080`.
  static String normalizeServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.contains('://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Map<String, String> toJson() => {'server': server, 'username': username, 'password': password};

  static XtreamCredentials? fromJson(Map<String, dynamic> json) {
    final server = json['server'], username = json['username'], password = json['password'];
    if (server is! String || username is! String || password is! String) return null;
    return XtreamCredentials(server: server, username: username, password: password);
  }
}

class XtreamException implements Exception {
  XtreamException(this.message);
  final String message;
  @override
  String toString() => message;
}

class XtreamAccount {
  XtreamAccount({required this.auth, this.status, this.expires, this.activeConnections, this.maxConnections});

  final bool auth;
  final String? status;
  final DateTime? expires;
  final int? activeConnections;
  final int? maxConnections;

  /// A refused line often answers `[]` or `{}` instead of `{"user_info": {"auth": 0}}`.
  factory XtreamAccount.fromJson(Object? json) {
    final user = json is Map ? json['user_info'] : null;
    if (user is! Map) return XtreamAccount(auth: false);
    final exp = lenientInt(user['exp_date']);
    return XtreamAccount(
      auth: lenientInt(user['auth']) == 1,
      status: lenientString(user['status']),
      expires: exp != null && exp > 0 ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null,
      activeConnections: lenientInt(user['active_cons']),
      maxConnections: lenientInt(user['max_connections']),
    );
  }
}

class LiveCategory {
  const LiveCategory({required this.id, required this.name});
  final String id;
  final String name;

  static LiveCategory? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = lenientString(json['category_id']);
    if (id == null) return null;
    return LiveCategory(id: id, name: lenientString(json['category_name']) ?? '');
  }
}

class Channel {
  const Channel({required this.id, required this.name, this.number, this.icon, this.categoryIds = const []});

  final int id;
  final String name;
  final String? number;
  final String? icon;
  final List<String> categoryIds;

  static Channel? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = lenientInt(json['stream_id']);
    if (id == null) return null;
    final ids = <String>{};
    final single = lenientString(json['category_id']);
    ids.addAll([?single]);
    final many = json['category_ids'];
    if (many is List) {
      for (final v in many) {
        final s = lenientString(v);
        if (s != null) ids.add(s);
      }
    }
    final icon = lenientString(json['stream_icon']);
    return Channel(
      id: id,
      name: (lenientString(json['name']) ?? '').trim(),
      number: lenientString(json['num']),
      icon: icon != null && icon.startsWith('http') ? icon : null,
      categoryIds: ids.toList(),
    );
  }

  /// Two letters for the logo tile when there's no logo.
  String get monogram {
    final words = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class Programme {
  const Programme({required this.title, required this.start, required this.end, this.description = ''});

  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  bool isLive(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  static Programme? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = lenientInt(json['start_timestamp']);
    final end = lenientInt(json['stop_timestamp']) ?? lenientInt(json['end_timestamp']);
    if (start == null || end == null || end <= start) return null;
    return Programme(
      title: _maybeBase64(lenientString(json['title']) ?? '').trim(),
      description: _maybeBase64(lenientString(json['description']) ?? '').trim(),
      start: DateTime.fromMillisecondsSinceEpoch(start * 1000),
      end: DateTime.fromMillisecondsSinceEpoch(end * 1000),
    );
  }

  /// `get_short_epg` sends titles base64 encoded; some panels don't.
  static String _maybeBase64(String s) {
    if (s.isEmpty || s.length % 4 != 0 || !RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(s)) return s;
    try {
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return s;
    }
  }
}

/// `player_api.php` for one line, plus its live stream URLs.
class XtreamClient {
  XtreamClient(this.credentials, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final XtreamCredentials credentials;
  final http.Client _http;
  static const userAgent = 'Lineup';

  /// Throws [XtreamException] when the login is wrong or the line isn't usable.
  Future<XtreamAccount> account() async {
    final info = XtreamAccount.fromJson(await _api(null));
    if (!info.auth) throw XtreamException('That username or password isn’t right.');
    final status = info.status;
    if (status != null && status.toLowerCase() != 'active') {
      throw XtreamException('This account is ${status.toLowerCase()}.');
    }
    return info;
  }

  Future<List<LiveCategory>> liveCategories() async =>
      _list(await _api('get_live_categories')).map(LiveCategory.fromJson).whereType<LiveCategory>().toList();

  Future<List<Channel>> liveStreams() async =>
      _list(await _api('get_live_streams')).map(Channel.fromJson).whereType<Channel>().toList();

  /// The next few programmes on a channel (`get_short_epg`), oldest first.
  Future<List<Programme>> shortEpg(int streamId, {int limit = 8}) async {
    final json = await _api('get_short_epg', {'stream_id': '$streamId', 'limit': '$limit'});
    final listings = json is Map ? json['epg_listings'] : null;
    final items = _list(listings).map(Programme.fromJson).whereType<Programme>().toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  /// `/live/<user>/<password>/<id>.ts`, each part escaped so a `/` or `?` can't split it.
  String liveUrl(int streamId) => [
        credentials.server,
        'live',
        Uri.encodeComponent(credentials.username),
        Uri.encodeComponent(credentials.password),
        '$streamId.ts',
      ].join('/');

  Uri apiUri(String? action, [Map<String, String> extra = const {}]) {
    final base = Uri.parse('${credentials.server}/player_api.php');
    return base.replace(queryParameters: {
      'username': credentials.username,
      'password': credentials.password,
      'action': ?action,
      ...extra,
    });
  }

  Future<Object?> _api(String? action, [Map<String, String> extra = const {}]) async {
    final uri = apiUri(action, extra);
    final http.Response res;
    try {
      res = await _http
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw XtreamException('Can’t reach ${Uri.tryParse(credentials.server)?.host ?? 'the server'}.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw XtreamException('That username or password isn’t right.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw XtreamException('The server answered ${res.statusCode}.');
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      throw XtreamException('That doesn’t look like an Xtream Codes server.');
    }
  }

  static List<Object?> _list(Object? json) => json is List ? json : const [];

  void close() => _http.close();
}

String? lenientString(Object? v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  if (v is num || v is bool) return '$v';
  return null;
}

int? lenientInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt();
  if (v is bool) return v ? 1 : 0;
  return null;
}

final _tagPattern = RegExp(r'^\s*([A-Za-z]{2,4})\s*[|:]\s*');

/// The country-style tag ("US") that a provider puts in front of most names ("US| LOCALS"),
/// or null when no one tag dominates. Names with other tags ("UK| …") keep theirs.
String? sharedTag(Iterable<String> names) {
  final counts = <String, int>{};
  var tagged = 0, total = 0;
  for (final n in names) {
    total++;
    final m = _tagPattern.firstMatch(n);
    if (m == null) continue;
    tagged++;
    final tag = m.group(1)!.toUpperCase();
    counts[tag] = (counts[tag] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  // Most names carry it, and it's at least three quarters of the tagged ones.
  if (top.value * 2 <= total || top.value * 4 < tagged * 3) return null;
  return top.key;
}

/// "US| NICK JR" -> "NICK JR" when [tag] is "US".
String stripTag(String name, String? tag) {
  if (tag == null) return name;
  final m = _tagPattern.firstMatch(name);
  if (m == null || m.group(1)!.toUpperCase() != tag) return name;
  final rest = name.substring(m.end).trim();
  return rest.isEmpty ? name : rest;
}
