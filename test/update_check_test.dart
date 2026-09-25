import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/app/app_version.dart';
import 'package:torrent_manager/utils/update_check.dart';

String _release(
  String tag, {
  List<String> assets = const <String>[],
  String? htmlUrl,
  String? body,
}) {
  final List<String> items = <String>[];
  for (final String a in assets) {
    items.add('{"name": "$a",'
        ' "browser_download_url": "https://example.com/$a",'
        ' "size": 12345678}');
  }
  return '{'
      '"tag_name": "$tag",'
      '"name": "Release $tag",'
      '"html_url": "${htmlUrl ??
          'https://github.com/punk64/TorrentManager/releases/tag/$tag'}",'
      '"body": "${body ?? 'notes of $tag'}",'
      '"assets": [${items.join(', ')}]'
      '}';
}

const String _apk = 'TorrentManager-V9.9.9-arm64-v8a.apk';

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
      final _FakeFetcher f = _FakeFetcher(_release('v9.9.9', assets: <String>[_apk]));
      final UpdateCheckResult r = await UpdateChecker(fetcher: f.call)
          .check(url: '', local: local);
      expect(r.status, UpdateCheckStatus.disabled);
      expect(r.hasUpdate, isFalse);
      expect(f.calls, 0, reason: '没配地址就不该联网');
    });

    test('地址只有空白 → 同样 disabled', () async {
      final _FakeFetcher f = _FakeFetcher(_release('v9.9.9', assets: <String>[_apk]));
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

    test('★ 纯文本版本号更大但没有安装包 → 不算更新', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => '1.2.3',
      ).check(url: 'https://x.example/v.txt', local: local);
      expect(r.hasUpdate, isFalse,
          reason: '解析不出 assets 就当没有可用安装包，不提示');
      expect(r.status, UpdateCheckStatus.noUpdate);
      expect(r.latest, '1.2.3');
    });

    test('★ 版本更新 + 带 apk → hasUpdate，并带出安装包信息', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async =>
            _release('1.0.0', assets: <String>[_apk], body: 'hello'),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.latest, '1.0.0');
      expect(r.apk, isNotNull);
      expect(r.apk!.name, _apk);
      expect(r.apk!.size, 12345678);
      expect(r.apk!.url, 'https://example.com/$_apk');
      expect(r.releaseUrl, contains('releases/tag/1.0.0'));
      expect(r.notes, 'hello');
    });

    test('★ assets 为空（只有源码 / draft）→ 不算更新', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => _release('9.9.9'),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isFalse);
      expect(r.status, UpdateCheckStatus.noUpdate);
      expect(r.reason, contains('安装包'));
      expect(r.latest, '9.9.9');
    });

    test('★ assets 里只有 .zip / .sha1 → 不算更新', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => _release(
          '9.9.9',
          assets: <String>['Source code.zip', '$_apk.sha1'],
        ),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isFalse);
      expect(r.apk, isNull);
    });

    test('★ ABI 匹配 → 选中对应的那个包', () async {
      final UpdateCheckResult r = await UpdateChecker(
        deviceAbi: 'arm64-v8a',
        fetcher: (String url) async => _release(
          '9.9.9',
          assets: <String>[
            'TorrentManager-V9.9.9-armeabi-v7a.apk',
            _apk,
          ],
        ),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.apk!.name, endsWith('arm64-v8a.apk'));
    });

    test('★ ABI 对不上 → 不算更新（装了也跑不起来）', () async {
      final UpdateCheckResult r = await UpdateChecker(
        deviceAbi: 'x86_64',
        fetcher: (String url) async => _release(
          '9.9.9',
          assets: <String>[_apk],
        ),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isFalse);
      expect(r.status, UpdateCheckStatus.noUpdate);
    });

    test('★ .sha1 侧车会被挂到对应安装包上', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async => _release(
          '9.9.9',
          assets: <String>[_apk, '$_apk.sha1'],
        ),
      ).check(url: 'https://x.example/v.json', local: local);
      expect(r.hasUpdate, isTrue);
      expect(r.apk!.sha1Url, 'https://example.com/$_apk.sha1');
    });

    test('GitHub Releases 的 {"tag_name":"v2.0.1"} → 兼容', () async {
      final UpdateCheckResult r = await UpdateChecker(
        fetcher: (String url) async =>
            '{"tag_name":"v2.0.1","name":"Release 2.0.1",'
            '"assets":[{"name":"a.apk","browser_download_url":"https://e/a.apk"}]}',
      ).check(url: 'https://api.github.com/repos/a/b/releases/latest',
          local: local);
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

  group('parseAssets', () {
    test('只留 .apk，并把 .sha1 挂上去', () {
      final List<UpdateAsset> a = UpdateChecker.parseAssets(<Object?>[
        <Object?, Object?>{
          'name': 'x.apk',
          'browser_download_url': 'https://e/x.apk',
          'size': 42,
        },
        <Object?, Object?>{
          'name': 'x.apk.sha1',
          'browser_download_url': 'https://e/x.apk.sha1',
        },
        <Object?, Object?>{
          'name': 'src.zip',
          'browser_download_url': 'https://e/src.zip',
        },
      ]);
      expect(a.length, 1);
      expect(a.single.name, 'x.apk');
      expect(a.single.size, 42);
      expect(a.single.sha1Url, 'https://e/x.apk.sha1');
    });

    test('不是数组 / 空 → 空列表', () {
      expect(UpdateChecker.parseAssets(null), isEmpty);
      expect(UpdateChecker.parseAssets('x'), isEmpty);
      expect(UpdateChecker.parseAssets(<Object?>[]), isEmpty);
    });
  });

  group('pickInstaller', () {
    final List<UpdateAsset> two = <UpdateAsset>[
      const UpdateAsset(name: 'a-armeabi-v7a.apk', url: 'u1'),
      const UpdateAsset(name: 'a-arm64-v8a.apk', url: 'u2'),
    ];

    test('没给 ABI → 取第一个', () {
      expect(UpdateChecker.pickInstaller(two, null)?.url, 'u1');
    });

    test('给了 ABI → 取匹配的', () {
      expect(UpdateChecker.pickInstaller(two, 'arm64-v8a')?.url, 'u2');
    });

    test('匹配不上 → null', () {
      expect(UpdateChecker.pickInstaller(two, 'x86_64'), isNull);
      expect(UpdateChecker.pickInstaller(const <UpdateAsset>[], 'arm64-v8a'),
          isNull);
    });
  });

  group('parseLatestVersion', () {
    test('各种形态都能抠出版本号', () {
      expect(UpdateChecker.parseLatestVersion('1.2.3'), '1.2.3');
      expect(UpdateChecker.parseLatestVersion('v1.2.3'), '1.2.3');
      expect(UpdateChecker.parseLatestVersion('{"latest":"3.0.0"}'), '3.0.0');
      expect(UpdateChecker.parseLatestVersion('{"latest_version":"3.0.0"}'),
          '3.0.0');

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
