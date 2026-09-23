







import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/app/app_version.dart';
import 'package:torrent_manager/utils/update_check.dart';


class _FakeFetcher {
  _FakeFetcher(this.body);

  final String body;
  int calls = 0;
  String? lastUrl;

  Future<String> call(String url) async {
    calls++;
    lastUrl = url;
    return body;
  }
}

void main() {
  const String local = '0.0.6';

  group('UpdateChecker 判定', () {
    test('地址为空 → disabled，且不发请求', () async {
      final _FakeFetcher f = _FakeFetcher('9.9.9');
      final UpdateCheckResult r = await UpdateChecker(fetcher: f.call)
          .check(url: '', local: local);
      expect(r.status, UpdateCheckStatus.disabled);
      expect(r.hasUpdate, isFalse);
      expect(f.calls, 0, reason: '没配地址就不该联网');
    });

    test('地址只有空白 → 同样 disabled', () async {
      final _FakeFetcher f = _FakeFetcher('9.9.9');
      final UpdateCheckResult r =
          await UpdateChecker(fetcher: f.call).check(url: '   ', local: local);
      expect(r.status, UpdateCheckStatus.disabled);
      expect(f.calls, 0);
    });

    test('请求抛异常 → failed，不向上抛', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => throw Exception('connection refused'),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.status, UpdateCheckStatus.failed);
      expect(r.hasUpdate, isFalse, reason: '失败绝不能变成"有更新"');
      expect(r.reason, contains('请求失败'));
    });

    test('响应解析不出版本号 → failed', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => 'server maintenance',
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.status, UpdateCheckStatus.failed);
      expect(r.hasUpdate, isFalse);
    });

    test('响应为空串 → failed', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '',
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.status, UpdateCheckStatus.failed);
      expect(r.hasUpdate, isFalse);
    });

    test('纯文本版本号更大 → hasUpdate', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '1.2.3',
      ).check(url: 'https://x.example/v.txt', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.latest, '1.2.3');
    });

    test('JSON {"version":...} → 取得到', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '{"version":"1.0.0","notes":"x"}',
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.latest, '1.0.0');
    });

    test('GitHub Releases 的 {"tag_name":"v2.0.1"} → 兼容', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '{"tag_name":"v2.0.1","name":"Release 2.0.1"}',
      ).check(url: 'https://api.github.com/repos/a/b/releases/latest', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.latest, '2.0.1', reason: 'v 前缀要剥掉');
    });

    test('远端版本相等 → 已是最新（不算更新）', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '0.0.6',
      ).check(url: 'https://x.example/v.txt', local: local);
      expect(r.status, UpdateCheckStatus.noUpdate);
      expect(r.hasUpdate, isFalse);
    });

    test('远端版本更小 → 已是最新（不倒退）', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '0.0.1',
      ).check(url: 'https://x.example/v.txt', local: local);
      expect(r.hasUpdate, isFalse);
    });

    test('请求确实打到了传入的地址', () async {
      final _FakeFetcher f = _FakeFetcher('0.0.6');
      await UpdateChecker(fetcher: f.call)
          .check(url: 'https://x.example/latest.json', local: local);
      expect(f.calls, 1);
      expect(f.lastUrl, 'https://x.example/latest.json');
    });
  });

  group('parseLatestVersion', () {
    test('各种形态都能抠出版本号', () {
      expect(UpdateChecker.parseLatestVersion('1.2.3'), '1.2.3');
      expect(UpdateChecker.parseLatestVersion('v1.2.3'), '1.2.3');
      expect(UpdateChecker.parseLatestVersion('{"latest":"3.0.0"}'), '3.0.0');
      expect(UpdateChecker.parseLatestVersion('{"latest_version":"3.0.0"}'), '3.0.0');
      
      expect(UpdateChecker.parseLatestVersion('{"version": 4.5.6'), '4.5.6');
    });

    test('抠不出就返回 null（不抛）', () {
      expect(UpdateChecker.parseLatestVersion(''), isNull);
      expect(UpdateChecker.parseLatestVersion(null), isNull);
      expect(UpdateChecker.parseLatestVersion('no version here'), isNull);
      expect(UpdateChecker.parseLatestVersion('{"foo":"bar"}'), isNull);
    });
  });

  group('默认配置', () {
    test('kUpdateCheckUrl 已接入本项目的 GitHub Releases（https）', () {
      
      
      
      
      
      expect(kUpdateCheckUrl, startsWith('https://'));
      expect(kUpdateCheckUrl, contains('punk64/TorrentManager'));
    });
  });
}
