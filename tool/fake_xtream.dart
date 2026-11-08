// A pretend Xtream Codes panel on localhost for trying the app without a real provider.
//
//   ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440 \
//     -t 120 -c:v libx264 -pix_fmt yuv420p -c:a aac -f mpegts tool/test.ts
//   dart run tool/fake_xtream.dart
//
// Then connect to http://127.0.0.1:8190 as demo / demo. Every channel plays tool/test.ts.
import 'dart:convert';
import 'dart:io';

const username = 'demo';
const password = 'demo';

final categories = [
  {'category_id': '1', 'category_name': 'News'},
  {'category_id': '2', 'category_name': 'Sports'},
  {'category_id': '3', 'category_name': 'Entertainment'},
  {'category_id': '4', 'category_name': 'Kids'},
  {'category_id': '5', 'category_name': 'Local'},
];

final channels = <(int, String, String, List<String>)>[
  (101, 'Metro News', '1', ['Evening Report', 'World Tonight', 'Metro Late']),
  (102, 'Global News 24', '1', ['Global Desk', 'Markets Close', 'Global Tonight']),
  (103, 'Business Now', '1', ['Closing Bell', 'Money Talk', 'Late Markets']),
  (110, 'City Sports 1', '2', ['Live: Basketball', 'Postgame Show', 'Sports Desk']),
  (111, 'City Sports 2', '2', ['Soccer Highlights', 'Live: Hockey', 'Hockey Extra']),
  (112, 'Fight Night', '2', ['Undercard', 'Main Event', 'Post Fight']),
  (120, 'Channel Five', '3', ['Quiz Hour', 'Cooking Tonight', 'Game Night']),
  (121, 'Drama One', '3', ['The Harbor', 'The Harbor', 'Night Shift']),
  (122, 'Movie Classics', '3', ['Feature Presentation', 'Late Feature', 'Midnight Movie']),
  (123, 'Comedy Central Hall', '3', ['Stand Up Hour', 'Sketch Show', 'Late Laughs']),
  (130, 'Kids Zone', '4', ['Animated Shorts', 'Bedtime Stories', 'Quiet Time']),
  (131, 'Toon Time', '4', ['Morning Toons', 'Adventure Hour', 'Classic Toons']),
  (140, 'Local 4', '5', ['Community Hour', 'Local 4 News', 'Local Weather']),
  (141, 'Local 9', '5', ['Evening Commute', 'Traffic and Weather', 'Local 9 Tonight']),
  (142, 'Local 11', '5', ['Town Hall', 'Local 11 News', 'Late Local']),
];

Future<void> main() async {
  final video = File('${File(Platform.script.toFilePath()).parent.path}/test.ts');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8190);
  stdout.writeln('Fake Xtream on http://127.0.0.1:8190 ($username / $password)');
  await for (final req in server) {
    final q = req.uri.queryParameters;
    final path = req.uri.path;
    stdout.writeln('${req.method} $path ${q['action'] ?? ''}');
    if (path == '/player_api.php') {
      final ok = q['username'] == username && q['password'] == password;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(ok ? _api(q) : {'user_info': {'auth': 0}}));
    } else if (path.startsWith('/live/$username/$password/') && video.existsSync()) {
      req.response.headers.contentType = ContentType('video', 'mp2t');
      await req.response.addStream(video.openRead());
    } else {
      req.response.statusCode = 404;
    }
    await req.response.close();
  }
}

Object _api(Map<String, String> q) {
  switch (q['action']) {
    case null:
      return {
        'user_info': {'auth': 1, 'status': 'Active', 'exp_date': '1893456000', 'active_cons': '0', 'max_connections': '2'}
      };
    case 'get_live_categories':
      return categories;
    case 'get_live_streams':
      return [
        for (final (num, name, cat, _) in channels)
          {'num': num, 'name': name, 'stream_id': num, 'stream_icon': '', 'category_id': cat}
      ];
    case 'get_short_epg':
      final id = int.tryParse(q['stream_id'] ?? '');
      final ch = channels.where((c) => c.$1 == id).firstOrNull;
      if (ch == null) return {'epg_listings': []};
      // Programmes of 30 to 90 minutes, staggered per channel, around now.
      final now = DateTime.now();
      var t = DateTime(now.year, now.month, now.day, now.hour).subtract(Duration(minutes: 30 * (ch.$1 % 3)));
      final out = <Map<String, Object>>[];
      for (var i = 0; i < 6; i++) {
        final len = Duration(minutes: [30, 60, 90][(ch.$1 + i) % 3]);
        final title = ch.$4[i % ch.$4.length];
        out.add({
          'title': base64.encode(utf8.encode(title)),
          'description': base64.encode(utf8.encode('$title on ${ch.$2}.')),
          'start_timestamp': t.millisecondsSinceEpoch ~/ 1000,
          'stop_timestamp': t.add(len).millisecondsSinceEpoch ~/ 1000,
        });
        t = t.add(len);
      }
      return {'epg_listings': out};
    default:
      return [];
  }
}
