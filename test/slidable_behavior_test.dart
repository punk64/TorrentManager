import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/widgets/slidable_tile.dart';

const Key kContent = Key('content');
const Key kContent2 = Key('content2');

const double kRowWidth = 300;

const double kExtentRatio = 0.5;
const double kExtent = kRowWidth * kExtentRatio;
const double kHalf = kExtent / 2;

const double kResistance = SlidableTile.defaultDragResistance;

Duration _clock = Duration.zero;

List<SlidableActionItem> _endActions({VoidCallback? onTap}) =>
    <SlidableActionItem>[
      SlidableActionItem(icon: Icons.delete, onPressed: onTap ?? () {}),
      SlidableActionItem(icon: Icons.pause, onPressed: onTap ?? () {}),
    ];

Widget _tile({
  required SlidableMotionKind motion,
  Key contentKey = kContent,
  bool withMargin = false,
  VoidCallback? onAction,
  Key? tileKey,
}) =>
    SizedBox(
      width: kRowWidth,
      child: SlidableTile(
        key: tileKey,
        motion: motion,
        extentRatio: kExtentRatio,
        margin: withMargin ? EdgeInsets.zero : null,
        contentBackground: const Color(0xFF202020),
        startActions: <SlidableActionItem>[
          SlidableActionItem(icon: Icons.search, onPressed: onAction ?? () {}),
        ],
        endActions: _endActions(onTap: onAction),
        child: Container(
          key: contentKey,
          height: 56,
          color: const Color(0xFF303030),
        ),
      ),
    );

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Future<TestGesture> _press(WidgetTester tester, Key key) async {
  _clock = Duration.zero;
  final TestGesture g = await tester.createGesture();
  await g.down(tester.getCenter(find.byKey(key)), timeStamp: _clock);
  _clock += const Duration(milliseconds: 60);
  await g.moveBy(const Offset(-20, 0), timeStamp: _clock);
  await tester.pump();
  return g;
}

Future<void> _move(
  WidgetTester tester,
  TestGesture g,
  double dx,
  Duration dt,
) async {
  _clock += dt;
  await g.moveBy(Offset(dx, 0), timeStamp: _clock);
  await tester.pump();
}

double _contentDx(WidgetTester tester, [Key key = kContent]) =>
    tester.getTopLeft(find.byKey(key)).dx;

double _endPaneLeft(WidgetTester tester) {
  final Iterable<double> lefts = tester
      .widgetList<Positioned>(find.byType(Positioned))
      .where((Positioned p) => p.top == 0 && p.bottom == 0 && p.width != null)
      .map((Positioned p) => p.left ?? double.nan);
  expect(lefts, isNotEmpty, reason: '没找到侧滑面板的 Positioned');
  return lefts.reduce((double a, double b) => a > b ? a : b);
}

void main() {
  setUp(() => _clock = Duration.zero);

  testWidgets('滑动①：拖动位移与手指成固定比例（跟手，含 dragResistance 阻尼）',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(_tile(motion: SlidableMotionKind.scroll)));

    final TestGesture g = await _press(tester, kContent);
    final double base = _contentDx(tester);
    await _move(tester, g, -30, const Duration(milliseconds: 60));
    final double moved = _contentDx(tester);

    expect(moved - base, closeTo(-30 / kResistance, 0.5));

    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('滑动②：松手按阈值吸附 / 快甩按速度吸附', (WidgetTester tester) async {
    Future<double> fresh(Key tileKey) async {
      await tester.pumpWidget(
        _host(_tile(motion: SlidableMotionKind.scroll, tileKey: tileKey)),
      );
      return _contentDx(tester);
    }

    double rest = await fresh(const ValueKey<String>('a'));
    TestGesture g = await _press(tester, kContent);
    await _move(tester, g, -15, const Duration(milliseconds: 400));
    expect((_contentDx(tester) - rest).abs(), lessThan(kHalf),
        reason: '前提：本次总位移必须小于展开宽度的一半');
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest, 0.5), reason: '未过半应回弹归位');

    rest = await fresh(const ValueKey<String>('b'));
    g = await _press(tester, kContent);

    const double move = kHalf * SlidableTile.defaultDragResistance * 1.4;
    await _move(tester, g, -move, const Duration(milliseconds: 400));
    expect((_contentDx(tester) - rest).abs(), greaterThan(kHalf),
        reason: '前提：本次总位移必须超过展开宽度的一半');
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest - kExtent, 0.5), reason: '过半应完全展开');
  });

  testWidgets('滑动②b：甩动分支（纯函数 —— widget 测试拿不到手指速度）',
      (WidgetTester tester) async {
    const double v = 1000;
    double t(double ratio, double vx) => SlidableTile.settleTarget(
          ratio: ratio,
          vx: vx,
          hasStart: true,
          hasEnd: true,
        );

    expect(t(0.1, -v), 1);

    expect(t(-0.1, v), -1);

    expect(t(0.2, 0), 0);
    expect(t(-0.2, 0), 0);

    expect(t(0.6, 0), 1);
    expect(t(-0.6, 0), -1);

    expect(
      SlidableTile.settleTarget(
          ratio: 0.9, vx: -v, hasStart: true, hasEnd: false),
      0,
      reason: '没有 endActions 时不应展开右侧',
    );
    expect(
      SlidableTile.settleTarget(
          ratio: 0, vx: v, hasStart: false, hasEnd: true),
      0,
      reason: '没有 startActions 时不应展开左侧',
    );
  });

  testWidgets('滑动③：未滑动时内容层铺满整行、按钮点不到',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(_host(
      _tile(
        motion: SlidableMotionKind.behind,
        withMargin: true,
        onAction: () => taps++,
      ),
    ));

    final Rect row = tester.getRect(find.byType(SlidableTile));
    final Rect content = tester.getRect(find.byKey(kContent));

    expect(content.left, closeTo(row.left, 0.1));
    expect(content.right, closeTo(row.right, 0.1));

    await tester.tapAt(Offset(row.left + 4, row.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(row.right - 4, row.center.dy));
    await tester.pump();
    expect(taps, 0, reason: '未滑动时点击行内不应触发侧滑按钮');
  });

  testWidgets('滑动④：同一时刻只允许一行展开', (WidgetTester tester) async {
    await tester.pumpWidget(_host(
      SizedBox(
        width: kRowWidth,
        child: SlidableAutoCloseGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _tile(motion: SlidableMotionKind.scroll),
              _tile(motion: SlidableMotionKind.scroll, contentKey: kContent2),
            ],
          ),
        ),
      ),
    ));

    final double rest1 = _contentDx(tester);
    final double rest2 = _contentDx(tester, kContent2);

    const double move = kHalf * SlidableTile.defaultDragResistance * 1.4;
    TestGesture g = await _press(tester, kContent);
    await _move(tester, g, -move, const Duration(milliseconds: 400));
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest1 - kExtent, 0.5));

    g = await _press(tester, kContent2);
    await _move(tester, g, -move, const Duration(milliseconds: 400));
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester, kContent2), closeTo(rest2 - kExtent, 0.5));
    expect(_contentDx(tester), closeTo(rest1, 0.5),
        reason: '滑开新的一行时，上一行应自动收起');
  });

  testWidgets('滑动⑥：已展开时反方向拖只回中，不跨到另一侧（需求 4）',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(_tile(motion: SlidableMotionKind.scroll)),
    );
    final double rest = _contentDx(tester);
    const double move = kHalf * SlidableTile.defaultDragResistance * 1.4;

    TestGesture g = await _press(tester, kContent);
    await _move(tester, g, -move, const Duration(milliseconds: 400));
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest - kExtent, 0.5),
        reason: '前提：右侧应已完全展开');

    g = await _press(tester, kContent);
    await _move(tester, g, move * 2, const Duration(milliseconds: 400));
    expect(_contentDx(tester), closeTo(rest, 1.0),
        reason: '已展开时反方向拖只应回到居中，不能一次跨到左侧');
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest, 0.5), reason: '松手后停在居中');

    g = await _press(tester, kContent);
    await _move(tester, g, move, const Duration(milliseconds: 400));
    await g.up();
    await tester.pumpAndSettle();
    expect(_contentDx(tester), closeTo(rest + kExtent, 0.5),
        reason: '再一次向右拖才应展开左侧（startActions）');
  });

  testWidgets('滑动⑤：两种 Motion 的按钮位移方式不同', (WidgetTester tester) async {
    for (final SlidableMotionKind m in SlidableMotionKind.values) {
      await tester.pumpWidget(
        _host(_tile(motion: m, tileKey: ValueKey<SlidableMotionKind>(m))),
      );

      final TestGesture g = await _press(tester, kContent);

      final double contentRest = _contentDx(tester);
      final double paneRest = _endPaneLeft(tester);

      await _move(tester, g, -30, const Duration(milliseconds: 60));

      final double contentDelta = _contentDx(tester) - contentRest;
      final double paneDelta = _endPaneLeft(tester) - paneRest;

      expect(contentDelta, closeTo(-30 / kResistance, 0.5),
          reason: '$m: 内容位移应跟手（含 1.3 阻尼）');

      if (m == SlidableMotionKind.scroll) {
        expect(paneDelta, closeTo(contentDelta, 0.5),
            reason: 'ScrollMotion：按钮应随卡片一起滑进来');
      } else {
        expect(paneDelta, closeTo(0, 0.5),
            reason: 'BehindMotion：按钮应固定不动，仅被卡片揭示');
      }

      await g.up();
      await tester.pumpAndSettle();
    }
  });
}
