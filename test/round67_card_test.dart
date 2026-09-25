import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/utils/strings.dart';
import 'package:torrent_manager/widgets/torrent_edit_fields.dart';

String _listPageSrc() =>
    File('lib/pages/torrent_list_page.dart').readAsStringSync();

FilledButton _modifyButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, S.editModify),
    );

int _nextDecl(String src, int from) {
  final RegExp re = RegExp(
      r'\n(?:  )?(?:static\s+)?(?:class\s+\w|Widget\s+\w|void\s+\w|Future<[^>]*>\s+\w|List<[^>]*>\s+\w|Map<[^>]*>\s+\w|Set<[^>]*>\s+\w|String\s+\w|bool\s+\w|int\s+\w|double\s+\w|Color\s+\w)');
  final Match? m = re.firstMatch(src.substring(from + 1));
  return m == null ? src.length : from + 1 + m.start;
}

void main() {
  tearDown(Get.reset);

  group('第 67 轮第四期 · 草稿按字段清（卡片逐项提交的前提）', () {
    test('清一个字段不影响另一个字段的草稿', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();

      tc.setDraft('h1', TorrentEditFields.kDlLimit, 100);
      tc.setDraft('h1', TorrentEditFields.kTags, 5);
      expect(tc.draftOf('h1', TorrentEditFields.kDlLimit), 100);

      tc.clearDraftKey('h1', TorrentEditFields.kDlLimit);
      expect(tc.draftOf('h1', TorrentEditFields.kDlLimit), isNull);
      expect(tc.draftOf('h1', TorrentEditFields.kTags), 5,
          reason: '逐项提交不能把别的字段草稿一起抹掉');

      tc.clearDraftKey('h1', TorrentEditFields.kTags);
      expect(tc.draftOf('h1', TorrentEditFields.kTags), isNull);
    });

    test('清空后整条草稿记录被移除（不留下空 Map）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();

      tc.setDraft('h1', TorrentEditFields.kDlLimit, 1);
      tc.clearDraftKey('h1', TorrentEditFields.kDlLimit);

      tc.clearDraftKey('h1', TorrentEditFields.kDlLimit);
      expect(tc.draftOf('h1', TorrentEditFields.kDlLimit), isNull);
    });

    test('clearDraft 是整条清（收起卡片时用）', () {
      Get.put(ServerController());
      final TorrentController tc = TorrentController();

      tc.setDraft('h1', TorrentEditFields.kDlLimit, 1);
      tc.setDraft('h1', TorrentEditFields.kRatioLimit, 2.0);
      tc.clearDraft('h1');
      expect(tc.draftOf('h1', TorrentEditFields.kDlLimit), isNull);
      expect(tc.draftOf('h1', TorrentEditFields.kRatioLimit), isNull);
    });
  });

  group('第 67 轮第四期 · baseline：草稿回填也能提交（本轮新语义）', () {
    testWidgets('输入框是草稿值、基准是服务端值 ⇒ 按钮要亮',
        (WidgetTester tester) async {

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditNumberField(
            label: S.fieldDlLimit,
            initial: 100,
            baseline: 50,
            unit: 'KB/s',
            onSave: (int v) async => true,
          ),
        ),
      ));

      expect(find.text('100'), findsOneWidget, reason: '草稿值要回填进输入框');
      expect(_modifyButton(tester).onPressed, isNotNull,
          reason: '草稿 100 ≠ 服务端 50 ⇒ 必须可提交');
    });

    testWidgets('输入框与服务端值一致 ⇒ 按钮置灰', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditNumberField(
            label: S.fieldDlLimit,
            initial: 50,
            baseline: 50,
            unit: 'KB/s',
            onSave: (int v) async => true,
          ),
        ),
      ));

      expect(_modifyButton(tester).onPressed, isNull);
    });

    testWidgets('不传 baseline 时回落 initial（详情页用法不受影响）',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditNumberField(
            label: S.fieldDlLimit,
            initial: 50,
            unit: 'KB/s',
            onSave: (int v) async => true,
          ),
        ),
      ));
      expect(_modifyButton(tester).onPressed, isNull);
    });

    testWidgets('分享率同样：草稿值回填、基准用服务端值',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditRatioField(
            label: S.fieldRatioLimit,
            initial: 3.0,
            baseline: 1.0,
            onSave: (double v) async => true,
          ),
        ),
      ));
      expect(_modifyButton(tester).onPressed, isNotNull);
    });

    test('值变化回调带出当前值（卡片靠它写草稿）', () {

      final String src =
          File('lib/widgets/torrent_edit_fields.dart').readAsStringSync();
      expect(src.contains('widget.onChanged?.call(_value)'), isTrue,
          reason: 'EditNumberField 输入时要回调 onChanged');
      expect(src.contains('final ValueChanged<double>? onChanged;'), isTrue,
          reason: 'EditRatioField 也要有 onChanged（切 chip 时回调）');
    });
  });

  group('第 67 轮第四期 · 点击热区（D9 方案 C）', () {
    test('整块点击 = 展开/收起，不再直接进详情', () {
      final String src = _listPageSrc();
      expect(src.contains('void _onCardTap(Torrent t)'), isTrue);

      expect(src.contains('onTap: () => _openDetail(t)'), isFalse,
          reason: '方案 C 之后卡片点击不再是"进详情"');
      expect(src.contains('onTap: () => _onCardTap(t)'), isTrue);
    });

    test('收起即丢弃草稿（D6），且只丢这一条', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('void _onCardTap(Torrent t)');
      final String body = src.substring(i, i + 700);
      expect(body.contains('ctrl.clearDraft(t.hash)'), isTrue,
          reason: '主动收起要丢草稿');
    });

    test('展开区吞掉点击（否则点「修改」会顺手收起卡片）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      final String body = src.substring(i, _nextDecl(src, i));
      expect(body.contains('HitTestBehavior.opaque'), isTrue);
      expect(body.contains('onTap: () {}'), isTrue,
          reason: '展开区外层要空吞点击，阻断冒泡（清单 6.1 第 1 条）');
    });

    test('进详情只走展开区底部按钮', () {
      final String src = _listPageSrc();
      expect(src.contains('S.viewDetail'), isTrue);
      expect(src.contains('_openDetail(t)'), isTrue);
    });

    test('展开时不在 build 里同步发请求（走 unawaited + 缓存）', () {
      final String src = _listPageSrc();
      expect(src.contains('unawaited(ctrl.ensureEditFields(t))'), isTrue,
          reason: '展开时按需补字段，但不能阻塞 UI 帧');
      final String ctrl =
          File('lib/controllers/torrent_controller.dart').readAsStringSync();
      expect(ctrl.contains('Future<void> ensureEditFields('), isTrue);
      expect(ctrl.contains('kDeepCacheTtl'), isTrue,
          reason: '必须有短缓存，否则每次展开都打网络');
    });

    test('多选态点卡片 = 勾选（与旧行为一致）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('void _onCardTap(Torrent t)');
      final String body = src.substring(i, i + 300);
      expect(body.contains('ctrl.toggleSelect(t.hash)'), isTrue);
    });
  });

  group('第 67 轮第四期 · 收起态布局（4.1）', () {
    test('底部区左右栏 1:1（原来是 2:1）', () {
      final String src = _listPageSrc();

      expect(src.contains('flex: 2,'), isFalse,
          reason: '4.1 要求底部区从 2:1 改成 1:1');
      expect(src.contains('flex: 1,'), isTrue);
    });

    test('右栏补了第 4 行（剩余量）', () {
      final String src = _listPageSrc();
      expect(src.contains('Icons.hourglass_bottom'), isTrue);
      expect(src.contains('t.amountLeft'), isTrue);
    });

    test('分类/标签 chip 上卡片，且不再挤在 _metaLine 里', () {
      final String src = _listPageSrc();
      expect(src.contains('List<Widget> _catChips('), isTrue);
      expect(src.contains('List<Widget> _tagChips('), isTrue);

      final int i = src.indexOf('String _metaLine(Torrent t)');
      final String body = src.substring(i, i + 500);
      expect(body.contains('t.category'), isFalse,
          reason: '分类已经做成 chip，_metaLine 里不该再重复一遍');
      expect(body.contains('t.tags'), isFalse);
    });

    test('标签 chip 按逗号切且限流 4 个（防止撑爆卡片）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('List<Widget> _tagChips(Torrent t)');
      final String body = src.substring(i, i + 900);
      expect(body.contains(".split(',')"), isTrue);
      expect(body.contains('.take(4)'), isTrue);
    });
  });

  group('第 67 轮第四期 · 多选栏批量入口（4.2 / D8）', () {
    test('批量入口挂在多选栏的按钮网格里（2026-09-24 起并入两行 4 列）', () {
      final String src = _listPageSrc();
      expect(src.contains('if (_selecting) _actionGrid()'), isTrue);
      expect(src.contains('Widget _actionGrid()'), isTrue);

      expect(src.contains('Widget _batchRow()'), isFalse);
      expect(src.contains('S.batchEdit'), isTrue);
      expect(src.contains('S.copyHash'), isTrue);
      expect(src.contains('S.copyMagnet'), isTrue);
      expect(src.contains('S.batchExport'), isTrue);
    });

    test('批量编辑直接复用第三期的面板', () {
      final String src = _listPageSrc();
      expect(src.contains('TorrentEditSheet.show(hashes)'), isTrue);
    });

    test('复制哈希：一行一条（多行粘贴也认得）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Future<void> _copyHashes()');
      final String body = src.substring(i, i + 600);
      expect(body.contains(r"join('\n')"), isTrue);
      expect(body.contains('Clipboard.setData'), isTrue);
    });

    test('复制磁力链：先脱敏再复制（passkey 不能外泄）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Future<void> _copyMagnets()');
      final String body = src.substring(i, i + 900);
      expect(body.contains('Formatter.maskUrl'), isTrue,
          reason: '磁力链带私人站 passkey，复制前必须脱敏（清单 6.4 第 17 条）');
      expect(body.contains('S.batchNoMagnet'), isTrue,
          reason: 'TR 侧可能一个磁力链都没有，要给提示而不是静默');
    });

    test('批量导出：按版本能力显隐 + 逐个导出 + 汇总', () {
      final String src = _listPageSrc();
      expect(src.contains('canExport'), isTrue);
      expect(src.contains('sc.qb.exportTorrent(t.hash)'), isTrue);
      expect(src.contains('FileExport.saveBytesAs'), isTrue);
      expect(src.contains('S.batchExportDone(ok, fail)'), isTrue);
      final int i = src.indexOf('Future<void> _batchExport()');
      final String body = src.substring(i, i + 500);
      expect(body.contains('S.exportVersionTooOld'), isTrue,
          reason: 'qB 4.5 以下要明确提示，不能静默失败');
    });

    test('批量导出传的是 Uint8List（saveBytesAs 的入参类型）', () {
      final String src = _listPageSrc();
      expect(src.contains('Uint8List.fromList(bytes)'), isTrue);
    });
  });

  group('第 67 轮第四期 · 删除弹窗危险警示（D8）', () {
    test('勾了删本地文件 ⇒ 红字警告 + 红色开关 + 红色确认', () {
      final String src = File('lib/utils/formatter.dart').readAsStringSync();
      expect(src.contains('S.deleteFilesWarn(count)'), isTrue);
      expect(src.contains('activeColor: Colors.red'), isTrue);
      expect(src.contains('foregroundColor: Colors.red'), isTrue);
      expect(src.contains('delFiles ? Colors.red : null'), isTrue);
    });

    test('二次点击确认仍在（删除底线，不许被这轮改掉）', () {
      final String src = _listPageSrc();
      expect(src.contains('void _onDeleteTapped()'), isTrue);
      expect(src.contains('_deleteArmed'), isTrue);
    });
  });

  group('第 67 轮第四期 · 展开区字段接线', () {
    test('路径/分类/标签/限速×2/分享率/做种时限 全部可编辑', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      final String body = src.substring(i, _nextDecl(src, i));
      expect(body.contains('_editCardPath'), isTrue);
      expect(body.contains('_editCardCategory'), isTrue);
      expect(body.contains('_editCardTags'), isTrue);
      expect(body.contains('EditNumberField'), isTrue);
      expect(body.contains('EditRatioField'), isTrue);
    });

    test('开关组按服务器能力裁剪，而不是按服务器类型一刀切', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Widget _detail(Torrent t, ColorScheme cs)');
      final String body = src.substring(i, _nextDecl(src, i));
      expect(body.contains('cap.forceStart'), isTrue);
      expect(body.contains('cap.sequentialDownload'), isTrue,
          reason: 'V6：TR 4.1 支持顺序下载，不能"TR 就隐藏"');
      expect(body.contains('cap.superSeeding'), isTrue);
    });

    test('提交成功后只清该字段草稿（不误伤别的未提交字段）', () {
      final String src = _listPageSrc();
      final int i = src.indexOf('Future<bool> _cardApply(');
      final String body = src.substring(i, i + 1200);
      expect(body.contains('clearDraftKey(t.hash, draftKey)'), isTrue);
      expect(body.contains('_refreshCardAfter'), isTrue,
          reason: 'qB 常"返回成功但状态没变"，要延迟再拉一次');
    });

    test('数字类字段把草稿写回 controller（列表回收后不丢输入）', () {
      final String src = _listPageSrc();
      expect(src.contains('ctrl.setDraft(t.hash, TorrentEditFields.kDlLimit'), isTrue);
      expect(src.contains('int _draftInt(Torrent t, String key, int fallback)'),
          isTrue);
      expect(
          src.contains('double _draftDouble(Torrent t, String key, double fallback)'),
          isTrue);
    });
  });
}
