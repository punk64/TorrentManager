import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/utils/app_update.dart';
import 'package:torrent_manager/utils/startup_update.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/utils/update_check.dart';

/// 形似 GitHub `/releases/latest` 的响应；[withApk] 为 false 时模拟
/// 「打了 tag 但没传安装包」的 Release（严格口径下不该提醒）。
String _githubBody(String tag, {bool withApk = true}) =>
    '{"tag_name": "$tag", "name": "$tag", '
    '"html_url": "https://github.com/punk64/TorrentManager/releases/tag/$tag", '
    '"assets": [${withApk
        ? '{"name": "TorrentManager-V$tag-arm64-v8a.apk", '
            '"browser_download_url": "https://example.com/a.apk", "size": 123}'
        : ''}]}';

Future<String> _ok(String tag, [void Function()? onCall]) async {
  onCall?.call();
  return _githubBody(tag);
}

Future<String> _boom() async => throw StateError('boom');

void main() {
  setUp(() {
    StartupUpdatePrompt.resetForTest();
    // 走平台通道拿 ABI 在测试里没人应答（会等满超时），直接指定。
    UpdateInstaller.testAbiOverride = 'arm64-v8a';
  });

  testWidgets('★ 有新版本 → 只挂提醒，不弹窗', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    final UpdateCheckResult? r =
        await StartupUpdatePrompt.runOnce(fetcher: (String url) => _ok('v9.9.9'));
    await tester.pumpAndSettle();

    expect(r?.hasUpdate, isTrue);
    expect(StartupUpdatePrompt.pending?.hasUpdate, isTrue);
    expect(StartupUpdatePrompt.pending?.latest, '9.9.9');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('★ 版本不比本机新 → 静默，不挂提醒', (WidgetTester tester) async {
    final UpdateCheckResult? r =
        await StartupUpdatePrompt.runOnce(fetcher: (String url) => _ok('v0.0.1'));

    expect(r?.hasUpdate, isFalse);
    expect(StartupUpdatePrompt.pending, isNull);
  });

  testWidgets('★ 有新版但 Release 没带安装包 → 不挂提醒',
      (WidgetTester tester) async {
    final UpdateCheckResult? r = await StartupUpdatePrompt.runOnce(
        fetcher: (String url) async => _githubBody('v9.9.9', withApk: false));

    expect(r?.hasUpdate, isFalse);
    expect(StartupUpdatePrompt.pending, isNull);
  });

  testWidgets('★ 网络失败 → 静默，不挂提醒', (WidgetTester tester) async {
    final UpdateCheckResult? r =
        await StartupUpdatePrompt.runOnce(fetcher: (String url) => _boom());

    expect(r?.hasUpdate, isFalse);
    expect(StartupUpdatePrompt.pending, isNull);
  });

  testWidgets('★ 幂等：同一进程内只发一次请求', (WidgetTester tester) async {
    int calls = 0;
    final UpdateCheckResult? first = await StartupUpdatePrompt.runOnce(
        fetcher: (String url) => _ok('v9.9.9', () => calls++));
    final UpdateCheckResult? second = await StartupUpdatePrompt.runOnce(
        fetcher: (String url) => _ok('v0.0.1', () => calls++));

    expect(calls, 1);
    expect(first?.latest, '9.9.9');
    expect(second?.latest, '9.9.9');
    expect(StartupUpdatePrompt.done, isTrue);
  });

  testWidgets('★ 失败后不再重试（失败也计入已检测）', (WidgetTester tester) async {
    int calls = 0;

    await StartupUpdatePrompt.runOnce(fetcher: (String url) async {
      calls++;
      throw StateError('boom');
    });
    expect(calls, 1);

    await StartupUpdatePrompt.runOnce(fetcher: (String url) => _ok('v9.9.9', () => calls++));

    expect(calls, 1);
    expect(StartupUpdatePrompt.pending, isNull);
  });

  testWidgets('★ showDetails：有待展示结果时才弹窗', (WidgetTester tester) async {
    await StartupUpdatePrompt.runOnce(
        fetcher: (String url) => _ok('v9.9.9'));

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (BuildContext c) {
        ctx = c;
        return const Scaffold(body: SizedBox());
      }),
    ));
    expect(find.byType(AlertDialog), findsNothing);

    unawaited(StartupUpdatePrompt.showDetails(ctx));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(S.updateFoundTitle('9.9.9')), findsOneWidget);
    expect(find.byKey(const Key('update_link')), findsOneWidget);
    expect(find.byKey(const Key('update_action')), findsOneWidget);

    await tester.tap(find.text(S.updateLater));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('★ showDetails：没有待展示结果时不弹窗', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final BuildContext ctx = tester.element(find.byType(Scaffold));

    await StartupUpdatePrompt.showDetails(ctx);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
