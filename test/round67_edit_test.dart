import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/server_capabilities.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

ServerData _qb() => ServerData(
      id: 'qb',
      name: 'qb',
      type: 'qbittorrent',
      host: '1.2.3.4',
      port: 8080,
    );

ServerData _tr() => ServerData(
      id: 'tr',
      name: 'tr',
      type: 'transmission',
      host: '1.2.3.4',
      port: 9091,
    );

void main() {
  tearDown(Get.reset);

  group('第 67 轮第三期 · 版本解析（多版本兼容的地基）', () {
    test('去掉 v 前缀与预发布后缀', () {
      expect(ServerCapabilities.parseVersion('v5.1.2'), <int>[5, 1, 2]);
      expect(ServerCapabilities.parseVersion('4.1.0-beta.1'), <int>[4, 1, 0]);
      expect(ServerCapabilities.parseVersion('2.11'), <int>[2, 11]);
      expect(ServerCapabilities.parseVersion(''), isEmpty);
      expect(ServerCapabilities.parseVersion(null), isEmpty);
    });

    test('位数不等时缺位按 0（2.11 == 2.11.0）', () {
      expect(ServerCapabilities.compare('2.11', '2.11.0'), 0);
      expect(ServerCapabilities.compare('2.8.14', '2.11.4'), lessThan(0));
      expect(ServerCapabilities.compare('4.1.0', '4.0.6'), greaterThan(0));
    });
  });

  group('第 67 轮第三期 · qB 端点门槛（V2/V3/V4）', () {
    test('setTags 要 WebAPI 2.11.4（qB 5.1）', () {
      expect(ServerCapabilities.qbCanSetTags('2.11.4'), isTrue);
      expect(ServerCapabilities.qbCanSetTags('2.11.3'), isFalse);
      expect(ServerCapabilities.qbCanSetTags('2.8.11'), isFalse);
      // 版本探测失败 ⇒ 乐观放行，靠 404 自适应兜底（不能因为探测失败就禁用功能）。
      expect(ServerCapabilities.qbCanSetTags(''), isTrue);
      expect(ServerCapabilities.qbCanSetTags('', unknownAs: false), isFalse);
    });

    test('export 要 WebAPI 2.8.14（qB 4.5）', () {
      expect(ServerCapabilities.qbCanExport('2.8.14'), isTrue);
      expect(ServerCapabilities.qbCanExport('2.8.5'), isFalse);
    });

    test('isPrivate 只有 5.0+ ⇒ 未知版本按"没有"处理（宁可不显示）', () {
      expect(ServerCapabilities.qbHasPrivateFlag('2.11.0'), isTrue);
      expect(ServerCapabilities.qbHasPrivateFlag('2.8.11'), isFalse);
      expect(ServerCapabilities.qbHasPrivateFlag(''), isFalse);
    });

    test('源码层：老 qB 必须能降级到 addTags/removeTags', () {
      final String qb = File('lib/data/qbittorrent/qb_method.dart')
          .readAsStringSync();
      expect(qb.contains("/api/v2/torrents/addTags"), isTrue);
      expect(qb.contains("/api/v2/torrents/removeTags"), isTrue);

      final String ctrl = File('lib/controllers/torrent_controller.dart')
          .readAsStringSync();
      expect(ctrl.contains('ServerCapabilities.qbCanSetTags'), isTrue,
          reason: 'V2：setTags 必须按接口版本选择，不能直接调');
      expect(ctrl.contains('_setTagsByDiff'), isTrue,
          reason: 'V2：老版本走差集降级');
    });
  });

  group('第 67 轮第三期 · TR 版本门槛（V6）', () {
    test('顺序下载 4.1 才有 ⇒ 4.0 上必须判定为不支持', () {
      expect(ServerCapabilities.trCanSequential('4.1.0'), isTrue);
      expect(ServerCapabilities.trCanSequential('4.0.6'), isFalse);
      expect(ServerCapabilities.trCanSequential('3.00'), isFalse);
    });

    test('能力包：顺序下载按版本显示，不再按服务器类型一刀切', () {
      expect(ServerCapabilities.of(_tr(), appVersion: '4.0.6')
          .sequentialDownload, isFalse);
      expect(ServerCapabilities.of(_tr(), appVersion: '4.1.0')
          .sequentialDownload, isTrue);
      expect(ServerCapabilities.of(_qb()).sequentialDownload, isTrue);
    });

    test('能力包：分类 / 强制做种 / 超级做种只有 qB', () {
      final CapabilitySet q = ServerCapabilities.of(_qb());
      final CapabilitySet t = ServerCapabilities.of(_tr(), appVersion: '4.1.0');
      expect(q.category, isTrue);
      expect(t.category, isFalse);
      expect(q.forceStart, isTrue);
      expect(t.forceStart, isFalse);
      expect(q.superSeeding, isTrue);
      expect(t.superSeeding, isFalse);
      expect(t.queuePosition, isTrue);
      expect(q.queuePosition, isFalse);
    });
  });

  group('第 67 轮第三期 · 控制器能力包接线', () {
    test('qB 老版本（WebAPI 2.8.11）⇒ setTags 降级、导出隐藏', () {
      final ServerController sc = ServerController();
      Get.put(sc);
      sc.current.value = _qb();
      sc.serverVersion['qb'] = '4.3.9';
      sc.serverApiVersion['qb'] = '2.8.11';
      final TorrentController tc = TorrentController();
      expect(tc.capabilities.setTagsReplace, isFalse);
      expect(tc.capabilities.exportTorrent, isFalse);
      expect(tc.capabilities.privateFlag, isFalse);
    });

    test('qB 5.1（WebAPI 2.11.4）⇒ 全部可用', () {
      final ServerController sc = ServerController();
      Get.put(sc);
      sc.current.value = _qb();
      sc.serverVersion['qb'] = '5.1.2';
      sc.serverApiVersion['qb'] = '2.11.4';
      final TorrentController tc = TorrentController();
      expect(tc.capabilities.setTagsReplace, isTrue);
      expect(tc.capabilities.exportTorrent, isTrue);
      expect(tc.capabilities.privateFlag, isTrue);
    });

    test('没取到版本 ⇒ 乐观放行（不能因为探测失败整块功能消失）', () {
      final ServerController sc = ServerController();
      Get.put(sc);
      sc.current.value = _qb();
      final TorrentController tc = TorrentController();
      expect(tc.capabilities.setTagsReplace, isTrue);
    });
  });

  group('第 67 轮第三期 · 草稿生命周期（D6）', () {
    test('读写 / 丢弃 / 清空', () {
      final EditDraft d = EditDraft();
      expect(d.isEmpty, isTrue);
      d.write(TorrentEditFields.kDlLimit, 2048);
      expect(d.read(TorrentEditFields.kDlLimit), 2048);
      expect(d.isNotEmpty, isTrue);
      expect(d.text(TorrentEditFields.kPath, '/mnt/a'), '/mnt/a');
      d.drop(TorrentEditFields.kDlLimit);
      expect(d.isEmpty, isTrue);
      d.write('a', 1);
      d.write('b', 2);
      d.clear();
      expect(d.length, 0);
    });

    test('草稿优先于种子当前值：轮询刷新不覆盖正在编辑的字段', () {
      final EditDraft d = EditDraft();
      d.write(TorrentEditFields.kPath, '/new/path');
      const String fromServer = '/old/path';
      final String shown =
          d.read(TorrentEditFields.kPath) as String? ?? fromServer;
      expect(shown, '/new/path');
    });
  });

  group('第 67 轮第三期 · 编辑组件行为', () {
    testWidgets('值没变时「修改」置灰；改了才可点', (WidgetTester tester) async {
      String? saved;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditTextField(
            label: '保存路径',
            initial: '/a/b',
            onSave: (String v) async {
              saved = v;
              return true;
            },
          ),
        ),
      ));

      final Finder btn = find.text(S.editModify);
      expect(btn, findsOneWidget);
      // 初始与 initial 一致 ⇒ 按钮不可用
      expect(tester.widget<FilledButton>(find.ancestor(
          of: btn, matching: find.byType(FilledButton))).enabled, isFalse);

      await tester.enterText(find.byType(TextField), '/a/c');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.ancestor(
          of: btn, matching: find.byType(FilledButton))).enabled, isTrue);

      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(saved, '/a/c');
    });

    testWidgets('开关失败会弹回原位（不出现"开着但没生效"的假象）',
        (WidgetTester tester) async {
      bool? asked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditSwitchRow(
            label: '强制做种',
            value: false,
            onChanged: (bool v) async {
              asked = v;
              return false; // 服务端失败
            },
          ),
        ),
      ));

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(asked, isTrue);
      // 失败 ⇒ 回到 false（不回弹就会出现"开着但没生效"）
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('第 67 轮第三期 · 导出落盘（3.5）', () {
    test('saveBytesAs 接受二进制（saveTextAs 只吃文本）', () {
      final String src =
          File('lib/utils/file_export.dart').readAsStringSync();
      expect(src.contains('static Future<String?> saveBytesAs'), isTrue);
      expect(src.contains('required Uint8List bytes'), isTrue);
      expect(src.contains('allowedExtensions = const <String>[\'torrent\']'),
          isTrue);
    });

    test('详情页导出不再写死 app 私有目录', () {
      final String src =
          File('lib/pages/torrent_info_page.dart').readAsStringSync();
      expect(src.contains('getApplicationDocumentsDirectory'), isFalse,
          reason: 'Android 11+ 上写 app 私有目录，用户在文件管理器里找不到');
      expect(src.contains('FileExport.saveBytesAs'), isTrue);
      expect(src.contains('capabilities.exportTorrent'), isTrue,
          reason: 'TR 没有导出接口 ⇒ 按钮必须隐藏（D4）');
    });
  });

  group('第 67 轮第三期 · 批量编辑（3.2）', () {
    test('部分失败汇总文案带成功/失败数', () {
      expect(S.batchDone(3, 0).contains('3'), isTrue);
      expect(S.batchDone(3, 2).contains('2'), isTrue);
      expect(S.batchFailList.isNotEmpty, isTrue);
    });

    test('批量面板：标签默认追加 + 按能力裁剪 + 逐种子提交', () {
      final String src =
          File('lib/widgets/torrent_edit_sheet.dart').readAsStringSync();
      expect(src.contains('showAppendSwitch: true'), isTrue,
          reason: '批量默认追加，整体替换会把各不相同的标签抹成一样');
      expect(src.contains('cap.forceStart'), isTrue);
      expect(src.contains('cap.sequentialDownload'), isTrue,
          reason: 'V6：顺序下载按版本显示');
      expect(src.contains('cap.superSeeding'), isTrue);
      // 逐种子提交 ⇒ 才能统计"哪些成功哪些失败"
      expect(src.contains('for (final String h in widget.hashes)'), isTrue);
      expect(src.contains('failed.add(name)'), isTrue);
    });
  });
}
