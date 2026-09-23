import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/app/theme.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';

FileNode? _find(List<FileNode> nodes, String path) {
  for (final FileNode n in nodes) {
    if (n.path == path) return n;
    final FileNode? r = _find(n.children, path);
    if (r != null) return r;
  }
  return null;
}

void main() {
  group('P1 · 服务端字段类型容错（TR / qB 通用）', () {
    test('★ 文件树的 size / progress 收到浮点或字符串不再抛异常', () {
      final List<FileNode> tree = buildFileTree(<Map<String, dynamic>>[
        <String, dynamic>{'name': 'd/a.bin', 'size': 1024.0, 'progress': '0.5'},
        <String, dynamic>{
          'name': 'd/sub/b.bin',
          'size': '2048',
          'progress': 0.25,
        },
      ]);

      expect(_find(tree, 'd/a.bin')?.size, 1024,
          reason: '浮点 `1024.0` 应被容错转成 int');
      expect(_find(tree, 'd/a.bin')?.progress, closeTo(0.5, 1e-9),
          reason: '字符串 `"0.5"` 应被容错转成 double');
      expect(_find(tree, 'd/sub/b.bin')?.size, 2048,
          reason: '字符串 `"2048"` 应被容错转成 int');

      final List<FileNode> tree2 = buildFileTree(<Map<String, dynamic>>[
        <String, dynamic>{'name': 'x.bin', 'size': 'abc', 'progress': null},
      ]);
      expect(_find(tree2, 'x.bin')?.size, 0);
      expect(_find(tree2, 'x.bin')?.progress, 0);
    });

    test('★ Formatter.getInt / getDouble 覆盖 qB · TR 的全部回法', () {
      final Map<String, dynamic> m = <String, dynamic>{
        'intVal': 12,
        'doubleVal': 34.9,
        'strVal': '56',
        'boolVal': true,
        'junk': 'xx',
        'nil': null,
      };
      expect(Formatter.getInt(m, 'intVal'), 12);
      expect(Formatter.getInt(m, 'doubleVal'), 34, reason: 'double 截断取整');
      expect(Formatter.getInt(m, 'strVal'), 56, reason: '数字字符串');
      expect(Formatter.getInt(m, 'junk', def: 7), 7, reason: '非数字 → 默认值');
      expect(Formatter.getInt(m, 'nil', def: 7), 7, reason: 'null → 默认值');
      expect(Formatter.getInt(m, 'missing', def: 9), 9, reason: '缺字段 → 默认值');
      expect(Formatter.getDouble(m, 'intVal'), 12.0);
      expect(Formatter.getDouble(m, 'strVal'), 56.0);
      expect(Formatter.getDouble(m, 'junk', def: 1.5), 1.5);
    });
  });

  group('P2 · 自定义主题透明度语义迁移', () {
    test('★ 老数据（无版本字段）读入时取补数', () {
      final CustomTheme? t = CustomTheme.fromJson(<String, dynamic>{
        'id': 'old-1',
        'name': '老主题',
        'themeMode': 1,
        'seed': 0xFF6750A4,

        'componentOpacity': 0.74,
      });
      expect(t, isNotNull);
      expect(t!.componentOpacity, closeTo(0.26, 1e-9),
          reason: '旧语义的不透明度 0.74 ⇒ 新语义的透明度 0.26');
      expect(
          CustomTheme.needsOpacityMigration(<String, dynamic>{
            'componentOpacity': 0.74,
          }),
          isTrue,
          reason: '缺版本字段即视为老数据，加载侧需回写一次');
    });

    test('★ 新格式带版本号，读回**不会再次取补**（值不来回跳）', () {
      const CustomTheme src = CustomTheme(
        id: 'new-1',
        name: '新主题',
        themeMode: 2,
        seed: Color(0xFF101010),
        fontColor: null,
        bgMode: 1,
        gradient1: Color(0xFF222222),
        gradient2: Color(0xFF333333),
        componentOpacity: 0.26,
        pageColors: <String, int>{'a': 0xFF445566},
      );
      final Map<String, dynamic> j = src.toJson();
      expect(j['opacitySemantics'], CustomTheme.opacitySemantics,
          reason: '落盘必须写明语义版本');
      expect(j['componentOpacity'], closeTo(0.26, 1e-9));
      expect(CustomTheme.needsOpacityMigration(j), isFalse);

      final CustomTheme? back = CustomTheme.fromJson(j);
      expect(back!.componentOpacity, closeTo(0.26, 1e-9),
          reason: '新数据不应被再次取补');

      expect(CustomTheme.fromJson(back.toJson())!.componentOpacity,
          closeTo(0.26, 1e-9));
    });
  });

  group('P3 · 清理项行为不变', () {
    test('★ setLastActivity：无活动时间恒返回「添加后从未活跃」', () {
      expect(Formatter.setLastActivity(null), S.activeNever);
      expect(Formatter.setLastActivity(0), S.activeNever);
      expect(Formatter.setLastActivity(-1), S.activeNever);

      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(Formatter.setLastActivity(now), S.activeJustNow);
      expect(Formatter.setLastActivity(now - 120), contains(S.unitMinute));
    });
  });
}
