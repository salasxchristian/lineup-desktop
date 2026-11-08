import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lineup_desktop/updater.dart';

void main() {
  group('isNewer', () {
    test('compares each number, not the text', () {
      expect(isNewer('0.10.0', '0.9.0'), isTrue);
      expect(isNewer('0.2.0', '0.1.9'), isTrue);
      expect(isNewer('1.0.0', '0.99.99'), isTrue);
    });
    test('same or older is not newer', () {
      expect(isNewer('0.1.0', '0.1.0'), isFalse);
      expect(isNewer('0.1.0', '0.2.0'), isFalse);
    });
    test('ignores build numbers and missing parts', () {
      expect(isNewer('0.1.0+5', '0.1.0'), isFalse);
      expect(isNewer('0.2', '0.1.9'), isTrue);
    });
  });

  group('Release', () {
    final json = {
      'tag_name': 'v0.2.0',
      'html_url': 'https://github.com/salasxchristian/lineup-desktop/releases/tag/v0.2.0',
      'body': 'Mini player\n',
      'assets': [
        {'name': 'LineupSetup-0.2.0.exe', 'browser_download_url': 'https://example.com/LineupSetup-0.2.0.exe'},
        {'name': 'Lineup-0.2.0-macos.zip', 'browser_download_url': 'https://example.com/Lineup-0.2.0-macos.zip'},
      ],
    };

    test('reads the version from the tag and finds this platform’s file', () {
      final r = Release.fromJson(json)!;
      expect(r.version, '0.2.0');
      expect(r.notes, 'Mini player');
      final file = Platform.isWindows ? 'LineupSetup-0.2.0.exe' : 'Lineup-0.2.0-macos.zip';
      expect(r.download, Uri.parse('https://example.com/$file'));
    });

    test('check marks a newer release available', () async {
      final u = Updater(httpClient: MockClient((req) async => http.Response(jsonEncode(json), 200)))..current = '0.1.0';
      await u.check();
      expect(u.status, UpdateStatus.available);
      expect(u.latest!.version, '0.2.0');
    });

    test('check is up to date on the same version', () async {
      final u = Updater(httpClient: MockClient((req) async => http.Response(jsonEncode(json), 200)))..current = '0.2.0';
      await u.check();
      expect(u.status, UpdateStatus.upToDate);
    });

    test('a failed check shows an error only when asked for', () async {
      final u = Updater(httpClient: MockClient((req) async => http.Response('', 500)))..current = '0.1.0';
      await u.check(quiet: true);
      expect(u.status, UpdateStatus.idle);
      await u.check();
      expect(u.status, UpdateStatus.failed);
      expect(u.error, isNotNull);
    });
  });
}
