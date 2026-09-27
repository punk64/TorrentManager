import 'package:flutter/material.dart';

import '../app/adaptive.dart';
import '../app/theme.dart';

class PathCandidate {
  const PathCandidate(this.path, this.source);

  final String path;

  final String source;
}

class PathCandidates {
  PathCandidates._();

  static const String srcDefault = '默认保存路径';

  static const String srcTemp = '临时路径';

  static const String srcCurrent = '当前';

  static const String unknown = '未指定';

  static List<PathCandidate> build({
    String? defaultPath,
    String? tempPath,
    Map<String, String>? categoryPaths,
    String? current,
    Map<String, int> seedPaths = const <String, int>{},
  }) {
    final List<PathCandidate> out = <PathCandidate>[];
    final Set<String> seen = <String>{};

    void add(String? raw, String source) {
      final String v = (raw ?? '').trim();
      if (v.isEmpty || v == unknown) return;
      if (!seen.add(v.toLowerCase())) return;
      out.add(PathCandidate(v, source));
    }

    add(defaultPath, srcDefault);
    add(tempPath, srcTemp);
    categoryPaths?.forEach((String name, String p) => add(p, '分类：$name'));
    add(current, srcCurrent);
    final List<MapEntry<String, int>> seeds = seedPaths.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    for (final MapEntry<String, int> e in seeds) {
      add(e.key, '种子 ×${e.value}');
    }
    return out;
  }
}

class PathDropdownField extends StatefulWidget {
  const PathDropdownField({
    super.key,
    required this.controller,
    required this.candidates,
    required this.label,
    this.hint,
    this.maxShow = 8,
    this.onPicked,
    this.onChanged,
  });

  final TextEditingController controller;

  final List<PathCandidate> candidates;

  final String label;

  final String? hint;

  final int maxShow;

  final VoidCallback? onPicked;

  final VoidCallback? onChanged;

  @override
  State<PathDropdownField> createState() => _PathDropdownFieldState();
}

class _PathDropdownFieldState extends State<PathDropdownField> {
  bool _open = false;
  bool _selfEdit = false;

  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus && mounted) setState(() => _open = false);
    });

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<PathCandidate> get _hits {
    final String q = widget.controller.text.trim().toLowerCase();
    final List<PathCandidate> all = widget.candidates
        .where((PathCandidate c) =>
            c.path.trim().isNotEmpty && c.path.trim().toLowerCase() != q)
        .toList();
    final Iterable<PathCandidate> matched = q.isEmpty
        ? all
        : all.where((PathCandidate c) =>
            c.path.toLowerCase().contains(q) ||
            c.source.toLowerCase().contains(q));
    return matched.toList();
  }

  void _pick(String path) {
    _selfEdit = true;
    widget.controller.text = path;
    widget.controller.selection =
        TextSelection.collapsed(offset: path.length);
    _selfEdit = false;
    setState(() => _open = false);
    widget.onPicked?.call();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<PathCandidate> hits = _hits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          maxLength: AppTheme.maxLenPath,
          buildCounter: AppTheme.noCounter,
          style: TextStyle(fontSize: af(context, 12), color: cs.onSurface),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint ?? '--',
            labelStyle: TextStyle(
                fontSize: af(context, 10.5), color: cs.onSurfaceVariant),
            floatingLabelStyle: TextStyle(
                fontSize: af(context, 10.5), color: cs.primary),
            helperText: '',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: _open
                      ? cs.primary.withValues(alpha: 0.65)
                      : cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: cs.primary.withValues(alpha: 0.65)),
            ),
            prefixIcon: widget.controller.text.isEmpty
                ? null
                : Icon(Icons.folder_outlined,
                    size: af(context, 15), color: cs.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: Icon(
                  _open ? Icons.expand_less : Icons.arrow_drop_down,
                  size: af(context, 20),
                  color: cs.onSurfaceVariant),
              onPressed: () => setState(() => _open = !_open),
            ),
          ),
          onChanged: (String v) {
            if (!_selfEdit) setState(() {});
            if (!_open && hits.isNotEmpty) setState(() => _open = true);
            widget.onChanged?.call();
          },
        ),
        if (_open && hits.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text('服务器识别到的路径 · 按输入过滤',
                      style: TextStyle(
                          fontSize: af(context, 10),
                          color: cs.onSurfaceVariant)),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 264),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                for (final PathCandidate c in hits)
                  InkWell(
                    onTap: () => _pick(c.path),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.subdirectory_arrow_right,
                                size: af(context, 14), color: cs.outline),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text.rich(
                                _highlight(context, c.path),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.tertiary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(c.source,
                                  style: TextStyle(
                                      fontSize: af(context, 9.5),
                                      color: cs.tertiary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  TextSpan _highlight(BuildContext context, String path) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String q = widget.controller.text.trim();
    final int i =
        q.isEmpty ? -1 : path.toLowerCase().indexOf(q.toLowerCase());
    final TextStyle base =
        TextStyle(fontSize: af(context, 12), color: cs.onSurfaceVariant);
    if (i <= 0) {
      return TextSpan(
          text: path,
          style: base.copyWith(
              fontWeight: FontWeight.w600, color: cs.onSurface));
    }
    return TextSpan(style: base, children: <InlineSpan>[
      TextSpan(
          text: path.substring(0, i),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      TextSpan(
          text: path.substring(i, i + q.length),
          style: TextStyle(
              fontWeight: FontWeight.w700, color: cs.primary)),
      TextSpan(text: path.substring(i + q.length)),
    ]);
  }
}
