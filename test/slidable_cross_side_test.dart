import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/widgets/slidable_tile.dart';

const Key kContent = Key('content');
const double kRowWidth = 300;
const double kExtentRatio = 0.5;
const double kExtent = kRowWidth * kExtentRatio;

const double kResistance = SlidableTile.defaultDragResistance;

Widget _tile(Key tileKey) => SizedBox(
      width: kRowWidth,
      child: SlidableTile(
        key: tileKey,
        motion: SlidableMotionKind.scroll,
        extentRatio: kExtentRatio,
        contentBackground: const Color(0xFF202020),
        startActions: <SlidableActionItem>[
          SlidableActionItem(icon: Icons.search, onPressed: () {}),
        ],
        endActions: <SlidableActionItem>[
          SlidableActionItem(icon: Icons.delete, onPressed: () {}),
        ],
        child: Container(
            key: kContent, height: 56, color: const Color(0xFF303030)),
      ),
    );

double _dx(WidgetTester tester) => tester.getTopLeft(find.byKey(kContent)).dx;

Future<TestGesture> _press(WidgetTester tester) async {
  final TestGesture g = await tester.createGesture();
  await g.down(tester.getCenter(find.byKey(kContent)));
  await g.moveBy(const Offset(-20, 0));
  await tester.pump();
  return g;
}

Future<void> _move(WidgetTester tester, TestGesture g, double dx) async {
  await g.moveBy(Offset(dx, 0));
  await tester.pump();
}

void main() {
  testWidgets('连续拖拽：左→右跨过零点后松手，应展开左侧面板',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: _tile(const Key('a'))))));

    final double rest = _dx(tester);
    final TestGesture g = await _press(tester);
    final double base = _dx(tester);

    await _move(tester, g, -100);

    expect(_dx(tester) - base, closeTo(-100 / kResistance, 1.0),
        reason: '前提：左滑应跟手（含 1.3 阻尼）');

    await _move(tester, g, 140);
    expect(_dx(tester) - base, greaterThan(1.0),
        reason: '同一个手势内应能跨过零点进入左侧，实际=${_dx(tester) - base}');

    await g.up();
    await tester.pumpAndSettle();

    expect(_dx(tester), closeTo(rest + kExtent, 1.0),
        reason: '跨过零点后松手应停在左侧展开态，而不是弹回中间');
  });

  testWidgets('连续拖拽：右→左跨过零点后松手，应展开右侧面板',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: _tile(const Key('b'))))));

    final double rest = _dx(tester);
    final TestGesture g = await _press(tester);
    final double base = _dx(tester);

    await _move(tester, g, 120);
    expect(_dx(tester) - base, greaterThan(1.0), reason: '前提：右滑应进入左侧面板');

    await _move(tester, g, -160);
    expect(_dx(tester) - base, lessThan(-1.0),
        reason: '同一个手势内应能跨过零点进入右侧');

    await g.up();
    await tester.pumpAndSettle();
    expect(_dx(tester), closeTo(rest - kExtent, 1.0),
        reason: '跨过零点后松手应停在右侧展开态');
  });

  testWidgets('未跨零点时仍按原来的过半阈值（不能误开另一侧）',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: _tile(const Key('c'))))));

    final double rest = _dx(tester);
    final TestGesture g = await _press(tester);

    await _move(tester, g, -50);
    await g.up();
    await tester.pumpAndSettle();
    expect(_dx(tester), closeTo(rest, 1.0), reason: '未过半应回弹归位');
  });

  testWidgets('纯函数：crossedZero 会放宽阈值', (WidgetTester tester) async {
    double t(double ratio, {bool crossed = false}) => SlidableTile.settleTarget(
          ratio: ratio,
          vx: 0,
          hasStart: true,
          hasEnd: true,
          crossedZero: crossed,
        );

    expect(t(0.3), 0);
    expect(t(-0.3), 0);
    expect(t(0.6), 1);

    expect(t(0.06, crossed: true), 1);
    expect(t(-0.06, crossed: true), -1);
    expect(t(0.01, crossed: true), 0, reason: '抖动级别（1%）仍不展开');
  });
}
