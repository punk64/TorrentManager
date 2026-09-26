import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/adaptive.dart';
import '../app/theme.dart';
import '../controllers/torrent_controller.dart';
import '../utils/strings.dart';
import 'bottom_panel.dart';

Future<void> showSortFilterPanel([BuildContext? context]) =>
    BottomPanel.show<void>(
      title: '排序与筛选',
      heightFactor: 0.85,
      child: const SortFilterPanel(),
      context: context,
    );

class _PanelMetrics {
  const _PanelMetrics(this.btnWidth);

  static const double listPadH = 12;

  static const double cardPadH = 14;

  static const double gap = 8;

  static const int cols = 4;

  static const int maxLabelChars = 4;

  static const double maxFontSize = 13;

  static const double minFontSize = 9;

  factory _PanelMetrics.forPanelWidth(double panelW) {
    final double gridW = panelW - 2 * listPadH - 2 * cardPadH;
    final double btn = (gridW - gap * (cols - 1)) / cols;
    return _PanelMetrics(btn);
  }

  final double btnWidth;

  double get hPad => (btnWidth * 0.08).clamp(3.0, 8.0);

  double get vPad => (btnWidth * 0.09).clamp(5.0, 9.0);

  double get fontSize => ((btnWidth - 2 * hPad) / maxLabelChars - 0.3)
      .clamp(minFontSize, maxFontSize);
}

class SortFilterPanel extends StatefulWidget {
  const SortFilterPanel({super.key});

  @override
  State<SortFilterPanel> createState() => _SortFilterPanelState();
}

class _SortFilterPanelState extends State<SortFilterPanel> {
  static const Duration _anim = Duration(milliseconds: 200);

  final TorrentController ctrl = Get.find<TorrentController>();

  bool _sortOpen = false;

  bool _statusOpen = false;

  final Set<FilterDim> _open = <FilterDim>{};

  _PanelMetrics _m = const _PanelMetrics(64);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        _m = _PanelMetrics.forPanelWidth(c.maxWidth);

        return Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    _PanelMetrics.listPadH,
                    4,
                    _PanelMetrics.listPadH,
                    af(context, 10),
                  ),
                  children: <Widget>[
                    _sortSection(),
                    _statusSection(),
                    for (final FilterDim d in FilterDim.values)
                      _facetSection(d, center: d != FilterDim.path),
                  ],
                ),
              ),
              _resultBar(),
            ],
          ),
        );
      },
    );
  }

  String get _sortSummary =>
      '${ctrl.sortKey.value.label} ${ctrl.sortDesc.value ? '↓' : '↑'}';

  String get _statusSummary {
    if (ctrl.filter.value == TorrentFilter.all && ctrl.subStates.isEmpty) {
      return '未筛选';
    }
    final int n = ctrl.subStates.length;
    return '${ctrl.filter.value.label}${n > 0 ? ' · $n' : ''}';
  }

  String _facetSummary(FilterDim d) {
    final int n = ctrl.selection(d).length;
    return n == 0 ? '未筛选' : '$n 个已选';
  }

  Widget _sortSection() {
    return _card(
      title: '排序方式',
      open: _sortOpen,
      summary: _sortSummary,
      onToggle: () => setState(() => _sortOpen = !_sortOpen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sortGrid(),
          SizedBox(height: af(context, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _btn(
                text: '升序',
                selected: !ctrl.sortDesc.value,
                onTap: () => ctrl.setSortDesc(false),
              ),
              SizedBox(width: af(context, 8)),
              _btn(
                text: '降序',
                selected: ctrl.sortDesc.value,
                onTap: () => ctrl.setSortDesc(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortGrid() {
    const int cols = _PanelMetrics.cols;
    const double spacing = _PanelMetrics.gap;
    const List<TorrentSortKey> keys = TorrentSortKey.values;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < keys.length; i += cols) {
      final List<TorrentSortKey> row =
          keys.skip(i).take(cols).toList(growable: false);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int j = 0; j < row.length; j++) ...<Widget>[
                if (j > 0) const SizedBox(width: spacing),
                SizedBox(
                  width: _m.btnWidth,
                  child: _btn(
                    text: row[j].label,
                    selected: ctrl.sortKey.value == row[j],
                    onTap: () => ctrl.setSortKey(row[j]),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _statusSection() {
    final int active =
        (ctrl.filter.value == TorrentFilter.all ? 0 : 1) + ctrl.subStates.length;
    return _card(
      title: S.filterStatusTitle,
      open: _statusOpen,
      summary: _statusSummary,
      badge: active,
      onToggle: () => setState(() => _statusOpen = !_statusOpen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusGrid(),
          SizedBox(height: af(context, 10)),
          _subStateChips(),
          if (ctrl.hasStatusFilter) ...<Widget>[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: ctrl.clearStatus,
                icon: Icon(Icons.filter_alt_off, size: af(context, 16)),
                label: Text(
                  S.filterStatusClear,
                  style: TextStyle(fontSize: _m.fontSize),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusGrid() {
    const int cols = _PanelMetrics.cols;
    const double spacing = _PanelMetrics.gap;
    const List<TorrentFilter> keys = TorrentFilter.values;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < keys.length; i += cols) {
      final List<TorrentFilter> row =
          keys.skip(i).take(cols).toList(growable: false);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int j = 0; j < row.length; j++) ...<Widget>[
                if (j > 0) const SizedBox(width: spacing),
                SizedBox(
                  width: _m.btnWidth,
                  child: _btn(
                    text: row[j].label,
                    selected: ctrl.filter.value == row[j],
                    onTap: () => ctrl.setFilter(row[j]),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _subStateChips() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> opts = ctrl.subStateOptions();
    if (opts.isEmpty) {
      return Text(
        S.filterSubNone,
        style: TextStyle(fontSize: _m.fontSize - 1, color: cs.outline),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          S.filterStatusSub,
          style: TextStyle(fontSize: _m.fontSize, color: cs.outline),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String v in opts)
              _btn(
                text: TorrentController.subStateLabel(v),
                selected: ctrl.subStates.contains(v),
                onTap: () => ctrl.toggleSubState(v),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          S.filterSubHint,
          style: TextStyle(fontSize: _m.fontSize - 1, color: cs.outline),
        ),
      ],
    );
  }

  Widget _facetSection(FilterDim d, {bool center = true}) {
    final List<FacetEntry> list = ctrl.facets(d);
    return _card(
      title: d.title,
      open: _open.contains(d),
      summary: _facetSummary(d),
      badge: ctrl.selection(d).length,
      onToggle: () => setState(() {
        if (!_open.remove(d)) _open.add(d);
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ctrl.hasFacet(d) ? () => ctrl.clearFacet(d) : null,
              icon: Icon(Icons.filter_alt_off, size: af(context, 16)),
              label: Text(
                '清除筛选',
                style: TextStyle(fontSize: _m.fontSize),
              ),
            ),
          ),
          const SizedBox(height: 2),
          list.isEmpty
              ? Text('（暂无数据）', style: TextStyle(fontSize: _m.fontSize))
              : Wrap(
                  alignment: center ? WrapAlignment.center : WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final FacetEntry e in list)
                      _btn(
                        text: '${e.value} (${e.count})',
                        selected: ctrl.selection(d).contains(e.value),
                        onTap: () => ctrl.toggleFacet(d, e.value),
                      ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _resultBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int shown = ctrl.visibleItems.length;
    final int total = ctrl.items.length;
    final bool active = ctrl.hasStatusFilter || ctrl.hasFacets;

    final Color bg = active ? cs.primary : cs.surfaceContainerHighest;
    final Color label = active ? cs.onPrimary : cs.onSurfaceVariant;
    final Color numColor = active ? cs.onPrimary : cs.primary;
    final Color iconColor = active ? cs.onPrimary : cs.primary;

    return Container(
      margin: EdgeInsets.fromLTRB(
        _PanelMetrics.listPadH,
        2,
        _PanelMetrics.listPadH,
        af(context, 10),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: af(context, 13),
        vertical: af(context, 9),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: active
              ? Colors.transparent
              : cs.outlineVariant.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            active ? Icons.filter_alt : Icons.filter_alt_outlined,
            size: af(context, 17),
            color: iconColor,
          ),
          SizedBox(width: af(context, 8)),
          Text(
            '筛选后',
            style: TextStyle(
              fontSize: af(context, 12),
              color: label,
            ),
          ),
          SizedBox(width: af(context, 5)),
          Text(
            '$shown',
            style: TextStyle(
              fontSize: af(context, 18),
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: numColor,
            ),
          ),
          Expanded(
            child: Text(
              ' / 共 $total 个',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: af(context, 12),
                color: label,
              ),
            ),
          ),
          InkWell(
            onTap: active ? _resetAll : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: af(context, 10),
                vertical: af(context, 5),
              ),
              child: Text(
                '重置',
                style: TextStyle(
                  fontSize: af(context, 13),
                  color: active ? cs.onPrimary : cs.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetAll() {
    HapticFeedback.selectionClick();
    ctrl.clearStatus();
    ctrl.clearFacets();
  }

  Widget _card({
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required Widget child,
    String? summary,
    int badge = 0,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: af(context, 10)),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle();
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  af(context, 14),
                  af(context, 13),
                  af(context, 12),
                  af(context, 13),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: af(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: (summary == null || summary.isEmpty)
                            ? const SizedBox.shrink()
                            : Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: af(context, 12),
                                  color: cs.outline,
                                ),
                              ),
                      ),
                    ),
                    if (badge > 0) ...<Widget>[
                      SizedBox(width: af(context, 6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: af(context, 6),
                          vertical: af(context, 1),
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(af(context, 8)),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            fontSize: af(context, 11),
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: af(context, 6)),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: _anim,
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.expand_more,
                        size: af(context, 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: _anim,
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        _PanelMetrics.cardPadH,
                        0,
                        _PanelMetrics.cardPadH,
                        af(context, 14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.7),
                          ),
                          SizedBox(height: af(context, 12)),
                          child,
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : cs.outlineVariant.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: _m.hPad, vertical: _m.vPad),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _m.fontSize,
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
