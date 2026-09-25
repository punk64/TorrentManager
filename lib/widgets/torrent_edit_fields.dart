import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class TorrentEditFields {
  TorrentEditFields._();

  static const String kPath = 'path';
  static const String kCategory = 'category';
  static const String kTags = 'tags';
  static const String kDlLimit = 'dlLimit';
  static const String kUpLimit = 'upLimit';
  static const String kRatioLimit = 'ratioLimit';
  static const String kSeedingTime = 'seedingTime';
  static const String kName = 'name';
}

class EditDraft {
  final Map<String, dynamic> _map = <String, dynamic>{};

  dynamic read(String key) => _map[key];

  String text(String key, String fallback) {
    final dynamic v = _map[key];
    return v is String ? v : fallback;
  }

  void write(String key, dynamic value) => _map[key] = value;

  void drop(String key) => _map.remove(key);

  void clear() => _map.clear();

  bool get isEmpty => _map.isEmpty;

  bool get isNotEmpty => _map.isNotEmpty;

  int get length => _map.length;

  Iterable<String> get keys => _map.keys;
}

class EditTextField extends StatefulWidget {
  const EditTextField({
    super.key,
    required this.label,
    required this.initial,
    this.hint,
    this.suffix,
    this.keyboardType,
    this.expands = false,
    this.onChanged,
    this.onDirtyChanged,
    this.onSave,
  });

  final String label;
  final String initial;
  final String? hint;
  final String? suffix;

  final TextInputType? keyboardType;

  final bool expands;

  final void Function(String value)? onChanged;

  final void Function(bool dirty)? onDirtyChanged;

  final Future<bool> Function(String value)? onSave;

  @override
  State<EditTextField> createState() => _EditTextFieldState();
}

class _EditTextFieldState extends State<EditTextField> {
  late final TextEditingController _c;
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant EditTextField old) {
    super.didUpdateWidget(old);

    if (!_dirty && widget.initial != old.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final Future<bool> Function(String)? save = widget.onSave;
    if (save == null || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    bool ok = false;
    try {
      ok = await save(_c.text.trim());
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok && _dirty) {
        _dirty = false;
        widget.onDirtyChanged?.call(false);
      }
    });
  }

  void _setDirty(bool v) {
    if (v == _dirty) return;
    _dirty = v;
    widget.onDirtyChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool canSave = _dirty && !_busy && widget.onSave != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: widget.expands
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(widget.label, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: widget.keyboardType,
              maxLines: widget.expands ? null : 1,
              minLines: widget.expands ? 2 : 1,
              style: TextStyle(fontSize: af(context, 11)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: af(context, 11)),
                suffixText: widget.suffix,
                suffixStyle: TextStyle(fontSize: af(context, 10), color: cs.outline),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                  borderSide: BorderSide(
                    color: _dirty ? Colors.deepOrange : cs.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                  borderSide: BorderSide(
                    color: _dirty ? Colors.deepOrange : cs.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (String v) {
                final bool now = v.trim() != widget.initial.trim();
                if (now != _dirty) setState(() => _setDirty(now));
                widget.onChanged?.call(v);
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: FilledButton.tonal(
              onPressed: canSave ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: TextStyle(fontSize: af(context, 11)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }
}

class EditNumberField extends StatefulWidget {
  const EditNumberField({
    super.key,
    required this.label,
    required this.initial,
    this.baseline,
    this.unit,
    this.zeroMeansUnlimited = false,
    this.compact = false,
    this.onChanged,
    this.onDirtyChanged,
    this.onSave,
  });

  final String label;

  final int initial;

  final bool compact;

  final int? baseline;

  final String? unit;

  final bool zeroMeansUnlimited;

  final ValueChanged<int>? onChanged;

  final void Function(bool dirty)? onDirtyChanged;

  final Future<bool> Function(int value)? onSave;

  @override
  State<EditNumberField> createState() => _EditNumberFieldState();
}

class _EditNumberFieldState extends State<EditNumberField> {
  late final TextEditingController _c;
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial <= 0 ? '' : '${widget.initial}');
  }

  @override
  void didUpdateWidget(covariant EditNumberField old) {
    super.didUpdateWidget(old);
    if (!_dirty && widget.initial != old.initial) {
      _c.text = widget.initial <= 0 ? '' : '${widget.initial}';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int get _value {
    final String s = _c.text.trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  void _markDirty() {
    final bool now = _value != (widget.baseline ?? widget.initial);
    widget.onChanged?.call(_value);
    if (now != _dirty) {
      setState(() {
        _dirty = now;
        widget.onDirtyChanged?.call(now);
      });
    }
  }

  Future<void> _submit() async {
    final Future<bool> Function(int)? save = widget.onSave;
    if (save == null || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    bool ok = false;
    try {
      ok = await save(_value);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok && _dirty) {
        _dirty = false;
        widget.onDirtyChanged?.call(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final bool changed = _dirty || _value != (widget.baseline ?? widget.initial);
    final bool canSave = changed && !_busy && widget.onSave != null;

    final bool cmp = widget.compact;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: cmp ? 2 : 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: cmp ? 40 : 88,
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: cmp ? 9.5 : 11),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: TextStyle(fontSize: cmp ? 10 : 11),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: cmp ? 5 : 8,
                  vertical: cmp ? 6 : 7,
                ),
                hintText: widget.zeroMeansUnlimited ? S.editUnlimitedHint : '0',
                hintStyle: TextStyle(fontSize: cmp ? 10 : 11),
                suffixText: widget.unit,
                suffixStyle: TextStyle(fontSize: af(context, 10), color: cs.outline),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                  borderSide: BorderSide(
                    color: _dirty ? Colors.deepOrange : cs.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                  borderSide: BorderSide(
                    color: _dirty ? Colors.deepOrange : cs.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (String _) => _markDirty(),
            ),
          ),
          if (widget.zeroMeansUnlimited) ...<Widget>[
            const SizedBox(width: 4),
            SizedBox(
              height: cmp ? 26 : 30,
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        _c.text = '';
                        _markDirty();
                      },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: cmp ? 5 : 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: TextStyle(fontSize: cmp ? 9 : 10),
                ),
                child: Text(S.editUnlimited),
              ),
            ),
          ],
          const SizedBox(width: 6),
          SizedBox(
            height: cmp ? 26 : 30,
            child: FilledButton.tonal(
              onPressed: canSave ? _submit : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: cmp ? 6 : 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontSize: cmp ? 10 : 11),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }
}

class EditRatioField extends StatefulWidget {
  const EditRatioField({
    super.key,
    required this.label,
    required this.initial,
    this.baseline,
    this.compact = false,
    this.onChanged,
    this.onDirtyChanged,
    this.onSave,
  });

  final String label;

  final double initial;

  final bool compact;

  final double? baseline;

  final ValueChanged<double>? onChanged;

  final void Function(bool dirty)? onDirtyChanged;

  final Future<bool> Function(double value)? onSave;

  @override
  State<EditRatioField> createState() => _EditRatioFieldState();
}

enum _RatioMode { global, custom, unlimited }

class _EditRatioFieldState extends State<EditRatioField> {
  late final TextEditingController _c;
  late _RatioMode _mode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _mode = _modeOf(widget.initial);
    _c = TextEditingController(
      text: _mode == _RatioMode.custom ? _fmt(widget.initial) : '',
    );
  }

  static _RatioMode _modeOf(double v) {
    if (v <= -1.5) return _RatioMode.global;
    if (v < 0) return _RatioMode.unlimited;
    return _RatioMode.custom;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  double get _value {
    switch (_mode) {
      case _RatioMode.global:
        return -2;
      case _RatioMode.unlimited:
        return -1;
      case _RatioMode.custom:
        return double.tryParse(_c.text.trim()) ?? -2;
    }
  }

  bool get _dirty => _value != (widget.baseline ?? widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final Future<bool> Function(double)? save = widget.onSave;
    if (save == null || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await save(_value);
    } catch (_) {

    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDirtyChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool canSave = _dirty && !_busy && widget.onSave != null;
    if (widget.compact) return _buildCompact(cs, canSave);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(widget.label, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final _RatioMode m in _RatioMode.values)
                      ChoiceChip(
                        label: Text(
                          m == _RatioMode.global
                              ? S.ratioModeGlobal
                              : (m == _RatioMode.unlimited
                                  ? S.ratioModeUnlimited
                                  : S.ratioModeCustom),
                          style: TextStyle(fontSize: af(context, 10)),
                        ),
                        selected: _mode == m,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (_) {
                          setState(() => _mode = m);
                          widget.onChanged?.call(_value);
                          widget.onDirtyChanged?.call(_dirty);
                        },
                      ),
                  ],
                ),
                if (_mode == _RatioMode.custom) ...<Widget>[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _c,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: af(context, 11)),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      hintText: '2.00',
                      hintStyle: TextStyle(fontSize: af(context, 11)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusTiny),
                        borderSide: BorderSide(
                          color: _dirty ? Colors.deepOrange : cs.outlineVariant,
                        ),
                      ),
                    ),
                    onChanged: (String _) {
                      setState(() {});
                      widget.onChanged?.call(_value);
                      widget.onDirtyChanged?.call(_dirty);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: FilledButton.tonal(
              onPressed: canSave ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: TextStyle(fontSize: af(context, 11)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(ColorScheme cs, bool canSave) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: af(context, 9.5)),
            ),
          ),
          Expanded(
            child: _mode == _RatioMode.custom
                ? TextField(
                    controller: _c,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: af(context, 10)),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 6),
                      hintText: '2.00',
                      hintStyle: TextStyle(fontSize: af(context, 10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusTiny),
                        borderSide: BorderSide(
                          color: _dirty ? Colors.deepOrange : cs.outlineVariant,
                        ),
                      ),
                    ),
                    onChanged: (String _) {
                      setState(() {});
                      widget.onChanged?.call(_value);
                      widget.onDirtyChanged?.call(_dirty);
                    },
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 26,
            child: OutlinedButton(
              onPressed: _busy ? null : _cycleMode,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontSize: af(context, 9)),
              ),
              child: Text(_modeName),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 26,
            child: FilledButton.tonal(
              onPressed: canSave ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(fontSize: af(context, 10)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }

  String get _modeName {
    switch (_mode) {
      case _RatioMode.global:
        return S.ratioModeGlobal;
      case _RatioMode.unlimited:
        return S.ratioModeUnlimited;
      case _RatioMode.custom:
        return S.ratioModeCustom;
    }
  }

  void _cycleMode() {
    final int i = _RatioMode.values.indexOf(_mode);
    setState(() {
      _mode = _RatioMode.values[(i + 1) % _RatioMode.values.length];
    });
    widget.onChanged?.call(_value);
    widget.onDirtyChanged?.call(_dirty);
  }
}

class EditSwitchRow extends StatefulWidget {
  const EditSwitchRow({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final bool value;
  final String? subtitle;

  final bool enabled;

  final Future<bool> Function(bool value)? onChanged;

  @override
  State<EditSwitchRow> createState() => _EditSwitchRowState();
}

class _EditSwitchRowState extends State<EditSwitchRow> {
  late bool _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant EditSwitchRow old) {
    super.didUpdateWidget(old);
    if (!_busy && widget.value != old.value) _v = widget.value;
  }

  Future<void> _flip(bool next) async {
    final Future<bool> Function(bool)? cb = widget.onChanged;
    if (cb == null || _busy) return;
    setState(() {
      _v = next;
      _busy = true;
    });
    bool ok = false;
    try {
      ok = await cb(next);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;

      if (!ok) _v = widget.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(widget.label, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: widget.subtitle == null
                ? const SizedBox.shrink()
                : Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant),
                  ),
          ),
          Switch(
            value: _v,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (widget.enabled && !_busy) ? _flip : null,
          ),
        ],
      ),
    );
  }
}

class EditSwitchChip extends StatefulWidget {
  const EditSwitchChip({
    super.key,
    required this.label,
    required this.value,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;

  final Future<bool> Function(bool value)? onChanged;

  @override
  State<EditSwitchChip> createState() => _EditSwitchChipState();
}

class _EditSwitchChipState extends State<EditSwitchChip> {
  late bool _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant EditSwitchChip old) {
    super.didUpdateWidget(old);

    if (!_busy && widget.value != old.value) _v = widget.value;
  }

  Future<void> _flip(bool next) async {
    final Future<bool> Function(bool)? cb = widget.onChanged;
    if (cb == null || _busy) return;
    setState(() {
      _v = next;
      _busy = true;
    });
    bool ok = false;
    try {
      ok = await cb(next);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;

      if (!ok) _v = widget.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool on = widget.enabled && !_busy;
    final bool active = _v && widget.enabled;
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? cs.primary : cs.outlineVariant),
        color: active ? cs.primary.withValues(alpha: 0.08) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.label,
            style: TextStyle(
              fontSize: af(context, 8),
              color: widget.enabled ? cs.onSurface : cs.outline,
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 26,
            height: 15,
            child: FittedBox(
              child: Switch(
                value: _v,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: on ? _flip : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditActionRow extends StatelessWidget {
  const EditActionRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(fontSize: af(context, 11))),
          ),
          Expanded(
            child: SelectableText(value, style: TextStyle(fontSize: af(context, 11))),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: TextStyle(fontSize: af(context, 11)),
              ),
              child: Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }
}

class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.tags,
    this.candidates = const <String>[],
    this.onChanged,
  });

  final List<String> tags;
  final List<String> candidates;

  final void Function(List<String> tags)? onChanged;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  late final TextEditingController _c;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController();
    _tags = List<String>.of(widget.tags);
  }

  @override
  void didUpdateWidget(covariant TagEditor old) {
    super.didUpdateWidget(old);

    if (!_sameSet(_tags, widget.tags)) _tags = List<String>.of(widget.tags);
  }

  static bool _sameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged?.call(List<String>.of(_tags));

  void _add(String raw) {
    final String v = raw.trim();
    if (v.isEmpty || _tags.contains(v)) {
      _c.clear();
      return;
    }
    setState(() {
      _tags.add(v);
      _c.clear();
    });
    _emit();
  }

  void _remove(String v) {
    setState(() => _tags.remove(v));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> spare = widget.candidates
        .where((String e) => !_tags.contains(e))
        .take(12)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String t in _tags)
              Chip(
                label: Text(t, style: TextStyle(fontSize: af(context, 10))),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onDeleted: () => _remove(t),
                deleteIconColor: cs.error,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _c,
                style: TextStyle(fontSize: af(context, 11)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  hintText: S.tagInputHint,
                  hintStyle: TextStyle(fontSize: af(context, 11)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                ),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 16),
                tooltip: S.tagAdd,
                onPressed: () => _add(_c.text),
              ),
            ),
          ],
        ),
        if (spare.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final String t in spare)
                ActionChip(
                  label: Text(t, style: TextStyle(fontSize: af(context, 10))),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => _add(t),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class EditDialogs {
  EditDialogs._();

  static Future<String?> text(
    BuildContext context, {
    required String title,
    String? label,
    String initial = '',
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) async {
    final TextEditingController c =
        TextEditingController(text: initial);
    String? out;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: af(context, 14))),
        content: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: af(context, 12)),
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            hintText: hint,
            labelStyle: TextStyle(fontSize: af(context, 11)),
            hintStyle: TextStyle(fontSize: af(context, 11)),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              out = c.text.trim();
              Navigator.of(ctx).pop();
            },
            child: Text(S.ok),
          ),
        ],
      ),
    );
    return (out == null || out!.isEmpty) ? null : out;
  }

  static Future<PathEditResult?> path(
    BuildContext context, {
    required String initial,
    required bool askMove,
    bool moveDefault = true,
  }) async {
    final TextEditingController c = TextEditingController(text: initial);
    bool move = moveDefault;
    bool ok = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.editPathTitle, style: TextStyle(fontSize: af(context, 14))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: c,
              style: TextStyle(fontSize: af(context, 12)),
              decoration: InputDecoration(
                isDense: true,
                labelText: S.fieldPath,
                labelStyle: TextStyle(fontSize: af(context, 11)),
              ),
            ),
            const SizedBox(height: 6),

            Text(
              askMove ? S.editPathMoveHint : S.editPathQbHint,
              style: TextStyle(fontSize: af(context, 10), color: Colors.deepOrange),
            ),
            if (askMove)
              StatefulBuilder(
                builder: (BuildContext ctx2, StateSetter set) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(S.editPathMove,
                      style: TextStyle(fontSize: af(context, 11))),
                  value: move,
                  onChanged: (bool v) => set(() => move = v),
                ),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              ok = true;
              Navigator.of(ctx).pop();
            },
            child: Text(S.editModify),
          ),
        ],
      ),
    );
    if (!ok) return null;
    final String p = c.text.trim();
    if (p.isEmpty || p == initial.trim()) return null;
    return PathEditResult(p, move: askMove ? move : true);
  }

  static Future<String?> category(
    BuildContext context, {
    required String initial,
    required List<String> candidates,
  }) async {
    final TextEditingController c = TextEditingController();
    String? picked = initial;
    bool ok = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.editCategoryTitle, style: TextStyle(fontSize: af(context, 14))),
        content: StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final String name in <String>['', ...candidates])
                    ChoiceChip(
                      label: Text(
                        name.isEmpty ? S.editCategoryNone : name,
                        style: TextStyle(fontSize: af(context, 10)),
                      ),
                      selected: picked == name,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => set(() => picked = name),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: c,
                style: TextStyle(fontSize: af(context, 12)),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: S.editCategoryNew,
                  labelStyle: TextStyle(fontSize: af(context, 11)),
                ),
                onChanged: (String v) {
                  final String t = v.trim();
                  if (t.isNotEmpty) set(() => picked = t);
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              ok = true;
              Navigator.of(ctx).pop();
            },
            child: Text(S.editModify),
          ),
        ],
      ),
    );
    if (!ok) return null;
    final String p = (picked ?? '').trim();
    if (p == initial.trim()) return null;
    return p;
  }

  static Future<TagEditResult?> tags(
    BuildContext context, {
    required List<String> initial,
    List<String> candidates = const <String>[],
    bool showAppendSwitch = false,
  }) async {
    List<String> cur = List<String>.of(initial);
    bool append = false;
    bool ok = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.editTagsTitle, style: TextStyle(fontSize: af(context, 14))),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (BuildContext ctx2, StateSetter set) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TagEditor(
                  tags: cur,
                  candidates: candidates,
                  onChanged: (List<String> v) => set(() => cur = v),
                ),
                if (showAppendSwitch)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(S.editTagsAppend,
                        style: TextStyle(fontSize: af(context, 11))),
                    subtitle: Text(S.editTagsAppendHint,
                        style: TextStyle(fontSize: af(context, 9))),
                    value: append,
                    onChanged: (bool v) => set(() => append = v),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              ok = true;
              Navigator.of(ctx).pop();
            },
            child: Text(S.editModify),
          ),
        ],
      ),
    );
    if (!ok) return null;
    return TagEditResult(cur, append: append);
  }
}

class PathEditResult {
  const PathEditResult(this.path, {required this.move});

  final String path;

  final bool move;
}

class TagEditResult {
  const TagEditResult(this.tags, {this.append = false});

  final List<String> tags;

  final bool append;
}

class EditLayout {
  EditLayout._();

  static bool gridOkOf(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return mq.size.width >= 360 && mq.textScaler.scale(1) <= 1.15;
  }
}

class ReadonlyKvGrid extends StatelessWidget {
  const ReadonlyKvGrid({
    super.key,
    this.fullRows = const <List<String>>[],
    this.pairs = const <List<String>>[],
    this.valueSize = 10.5,
  });

  final List<List<String>> fullRows;

  final List<List<String>> pairs;

  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    Widget halfCell(String k, String v) => Row(
          children: <Widget>[
            SizedBox(
              width: 50,
              child: Text(
                k,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: af(context, 9), color: cs.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: valueSize),
              ),
            ),
          ],
        );

    Widget fullCell(String k, String v) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 88,
              child: Text(k, style: TextStyle(fontSize: af(context, 11))),
            ),
            Expanded(
              child: SelectableText(v, style: TextStyle(fontSize: af(context, 11))),
            ),
          ],
        );

    final List<Widget> out = <Widget>[
      for (final List<String> r in fullRows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: fullCell(r[0], r[1]),
        ),
    ];

    if (!EditLayout.gridOkOf(context)) {
      for (final List<String> p in pairs) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: fullCell(p[0], p[1]),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
    }

    for (int i = 0; i < pairs.length; i += 2) {
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: halfCell(pairs[i][0], pairs[i][1])),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < pairs.length
                  ? halfCell(pairs[i + 1][0], pairs[i + 1][1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}

class EditSectionCard extends StatelessWidget {
  const EditSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.dense = false,
  });

  final String title;

  final Widget child;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double h = dense ? 8 : 10;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: dense ? 6 : 9),
      padding: EdgeInsets.fromLTRB(h, dense ? 6 : 8, h, dense ? 7 : 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.75),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: dense ? 10 : 12,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: dense ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 4 : 6),
          child,
        ],
      ),
    );
  }
}
