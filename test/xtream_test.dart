import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lineup_desktop/guide_layout.dart';
import 'package:lineup_desktop/xtream.dart';

void main() {
  group('XtreamCredentials', () {
    test('adds a scheme and drops trailing slashes', () {
      expect(XtreamCredentials.normalizeServer(' example.com:8080/ '), 'http://example.com:8080');
      expect(XtreamCredentials.normalizeServer('https://live.example.com//'), 'https://live.example.com');
    });
  });

  group('parsing', () {
    test('channels decode leniently and skip entries without an id', () {
      final items = [
        {'stream_id': '12', 'num': 4, 'name': ' Metro News ', 'stream_icon': 'http://x/logo.png', 'category_id': '3'},
        {'stream_id': 13, 'name': 'Sports', 'stream_icon': '', 'category_ids': [3, '5']},
        {'name': 'no id'},
        'junk',
      ].map(Channel.fromJson).whereType<Channel>().toList();
      expect(items.length, 2);
      expect(items[0].id, 12);
      expect(items[0].number, '4');
      expect(items[0].name, 'Metro News');
      expect(items[0].categoryIds, ['3']);
      expect(items[1].icon, isNull);
      expect(items[1].categoryIds, containsAll(['3', '5']));
    });

    test('monograms', () {
      expect(const Channel(id: 1, name: 'City Sports 1').monogram, 'CS');
      expect(const Channel(id: 1, name: 'HBO').monogram, 'HB');
      expect(const Channel(id: 1, name: 'US| ESPN').monogram, 'UE');
    });

    test('a refused login answers [] and reads as auth false', () {
      expect(XtreamAccount.fromJson([]).auth, isFalse);
      final ok = XtreamAccount.fromJson({
        'user_info': {'auth': 1, 'status': 'Active', 'exp_date': '1893456000', 'max_connections': '2'}
      });
      expect(ok.auth, isTrue);
      expect(ok.maxConnections, 2);
      expect(ok.expires, isNotNull);
    });

    test('short EPG titles are base64 decoded', () {
      final p = Programme.fromJson({
        'title': base64.encode(utf8.encode('Evening Report')),
        'description': 'plain text, not base64!',
        'start_timestamp': '1000',
        'stop_timestamp': '4600',
      })!;
      expect(p.title, 'Evening Report');
      expect(p.description, 'plain text, not base64!');
      expect(p.end.difference(p.start), const Duration(hours: 1));
    });
  });

  group('XtreamClient', () {
    test('escapes the login in stream URLs', () {
      final c = XtreamClient(XtreamCredentials(server: 'host:80', username: 'a/b', password: 'p?w'));
      expect(c.liveUrl(7), 'http://host:80/live/a%2Fb/p%3Fw/7.ts');
    });

    test('a wrong login throws a readable error', () async {
      final mock = MockClient((_) async => http.Response(jsonEncode({'user_info': {'auth': 0}}), 200));
      final c = XtreamClient(XtreamCredentials(server: 'h', username: 'u', password: 'p'), httpClient: mock);
      expect(c.account(), throwsA(isA<XtreamException>()));
    });

    test('short EPG comes back sorted', () async {
      final mock = MockClient((req) async {
        expect(req.url.queryParameters['action'], 'get_short_epg');
        expect(req.url.queryParameters['stream_id'], '9');
        return http.Response(jsonEncode({
          'epg_listings': [
            {'title': 'B', 'start_timestamp': 2000, 'stop_timestamp': 3000},
            {'title': 'A', 'start_timestamp': 1000, 'stop_timestamp': 2000},
          ]
        }), 200);
      });
      final c = XtreamClient(XtreamCredentials(server: 'h', username: 'u', password: 'p'), httpClient: mock);
      final list = await c.shortEpg(9);
      expect(list.map((p) => p.title), ['A', 'B']);
    });
  });

  group('shared tag', () {
    test('one tag on most names is dropped', () {
      final tag = sharedTag(['US| LOCALS', 'US| NEWS NETWORK', 'US| KIDS', 'US| SPORTS', 'ES| DEPORTES']);
      expect(tag, 'US');
      expect(stripTag('US| NICK JR', tag), 'NICK JR');
      expect(stripTag('UK| BBC ONE', tag), 'UK| BBC ONE');
    });

    test('mixed tags are kept', () {
      expect(sharedTag(['US| A', 'UK| B']), isNull);
      expect(sharedTag(['News', 'Sports']), isNull);
    });
  });

  group('guide layout', () {
    final now = DateTime(2026, 11, 7, 18, 36);
    final start = guideStart(now);

    test('the window starts at the current half hour', () {
      expect(start, DateTime(2026, 11, 7, 18, 30));
      expect(nowFraction(now, start), closeTo(0.05, 1e-9));
      expect(guideStart(DateTime(2026, 11, 7, 18, 5)), DateTime(2026, 11, 7, 18, 0));
    });

    test('blocks are clipped to the window and marked live or future', () {
      Programme p(int fromMin, int toMin) => Programme(
          title: '$fromMin', start: start.add(Duration(minutes: fromMin)), end: start.add(Duration(minutes: toMin)));
      final blocks = layoutBlocks([p(-90, -10), p(-60, 30), p(30, 90), p(90, 200), p(200, 260)], start, now);
      expect(blocks.length, 3);
      // Started an hour before the window: cropped to the left edge.
      expect(blocks[0].left, 0);
      expect(blocks[0].width, closeTo(0.25, 1e-9));
      expect(blocks[0].state, BlockState.live);
      expect(blocks[0].elapsed, closeTo(0.2, 1e-9));
      expect(blocks[1].state, BlockState.future);
      expect(blocks[2].left + blocks[2].width, closeTo(1, 1e-9));
    });

    test('four half-hour slots', () {
      final slots = guideSlots(start);
      expect(slots.map((s) => s.$1), [0, 0.25, 0.5, 0.75]);
    });
  });
}
