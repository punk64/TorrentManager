import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/torrent_controller.dart';
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
  final TorrentController ctrl = Get.find<TorrentController>();

  
  bool _sortOpen = true;

  
  
  final Set<FilterDim> _open = <FilterDim>{};

  
  
  
  
  _PanelMetrics _m = const _PanelMetrics(64);

  @override
  Widget build(BuildContext context) {
    
    
    
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        _m = _PanelMetrics.forPanelWidth(c.maxWidth);
        
        
        return Obx(
          () => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              _PanelMetrics.listPadH,
              4,
              _PanelMetrics.listPadH,
              24,
            ),
            children: <Widget>[
              _sortSection(),
              for (final FilterDim d in FilterDim.values)
                _facetSection(d, center: d != FilterDim.path),
              const SizedBox(height: 4),
              _footer(),
            ],
          ),
        );
      },
    );
  }

  

  Widget _sortSection() {
    return _card(
      title: '排序方式',
      open: _sortOpen,
      onToggle: () => setState(() => _sortOpen = !_sortOpen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          
          
          
          
          
          
          _sortGrid(),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _btn(
                text: '升序',
                selected: !ctrl.sortDesc.value,
                onTap: () => ctrl.setSortDesc(false),
              ),
              const SizedBox(width: 8),
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

  

  Widget _facetSection(FilterDim d, {bool center = true}) {
    final List<FacetEntry> list = ctrl.facets(d);
    return _card(
      title: d.title,
      open: _open.contains(d),
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
              icon: const Icon(Icons.filter_alt_off, size: 16),
              
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
              
              
              alignment:
                  center ? WrapAlignment.center : WrapAlignment.start,
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

  Widget _footer() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: ctrl.hasFacets ? ctrl.clearFacets : null,
        icon: const Icon(Icons.filter_alt_off, size: 18),
        
        
        
        label: Text('清除全部筛选', style: TextStyle(fontSize: _m.fontSize)),
      ),
    );
  }

  

  
  Widget _card({
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        
        borderRadius: BorderRadius.circular(AppTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                
                
                
                padding: const EdgeInsets.fromLTRB(
                  _PanelMetrics.cardPadH,
                  0,
                  _PanelMetrics.cardPadH,
                  14,
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
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
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
    return Material(
      
      
      
      color: selected ? cs.primary : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : cs.outlineVariant.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          
          
          
          
          padding: EdgeInsets.symmetric(horizontal: _m.hPad, vertical: _m.vPad),
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
    );
  }
}
