import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../utils/strings.dart';

/// 第 67 轮 · 可复用编辑组件（清单 3.1）。
///
/// ★ 卡片展开区（第四期）与种子详情页（第三期）**共用**这些组件，
///   差异只在草稿存哪：详情页存页面 state（不会因滚动被回收），
///   列表卡片必须存 controller（`TorrentController.setDraft`），
///   否则 ListView 回收重建后草稿会丢甚至串到别的卡片。
///
/// ★ 尺寸对齐详情页的 `_kv`：label 宽 88 + `Expanded` 内容区 + 字号 11。
///
/// ★ 所有文案走 `S`（内部 `L.pick`），不碰 `en_map`。
class TorrentEditFields {
  TorrentEditFields._();

  /// 草稿字段的 key（避免各处手写字符串打错）。
  static const String kPath = 'path';
  static const String kCategory = 'category';
  static const String kTags = 'tags';
  static const String kDlLimit = 'dlLimit';
  static const String kUpLimit = 'upLimit';
  static const String kRatioLimit = 'ratioLimit';
  static const String kSeedingTime = 'seedingTime';
  static const String kName = 'name';
}

/// 草稿容器：读优先级 `draft[key] ?? 种子当前值`，
/// 正在编辑的字段因此天然不被 3 秒轮询覆盖（D6）。
class EditDraft {
  final Map<String, dynamic> _map = <String, dynamic>{};

  dynamic read(String key) => _map[key];

  /// 读字符串草稿（没有就回落 [fallback]）。
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

/// A 类 · 行内直改 + 尾部「修改」提交（短值，单行放得下）。
///
/// ★ 提交只能靠点「修改」：**不做失焦自动提交**（防止输一半就发出去）。
/// ★ 值没变时「修改」置灰，避免误提交。
/// ★ 外部初始值变化（3 秒轮询）时：只有**用户没动过**才同步，动了就保留输入。
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

  /// 路径这类长文本：整行抬高成多行输入。
  final bool expands;

  final void Function(String value)? onChanged;

  /// 脏态变化回调（页面据此显示「有未保存改动」提示）。
  final void Function(bool dirty)? onDirtyChanged;

  /// 返回 true = 提交成功（调用方负责刷新与 toast）。
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
    // ★ 用户没动过才跟随外部刷新；动过就保留输入（草稿不被轮询覆盖）。
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
            child: Text(widget.label, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: widget.keyboardType,
              maxLines: widget.expands ? null : 1,
              minLines: widget.expands ? 2 : 1,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                hintText: widget.hint,
                hintStyle: const TextStyle(fontSize: 11),
                suffixText: widget.suffix,
                suffixStyle: TextStyle(fontSize: 10, color: cs.outline),
                // ★ 脏态橙色：让用户一眼看出"改了还没提交"。
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
                textStyle: const TextStyle(fontSize: 11),
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

/// 数字编辑行：限速 / 做种时限这类「填数字 + 单位」，带「不限」快捷（填 0）。
///
/// ★ 限速单位统一 **KB/s**（调用方负责 ×1024 转给 qB）。
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

  /// 输入框初值（整数；0 表示不限）。
  final int initial;

  /// 紧凑模式（概览 Tab v3 布局定稿）：label 收窄到 38、「不限」/「修改」按钮缩小 ⇒
  /// 每格约 163dp 的两列网格里也能放下（10.5 排布规则第 3 条）。
  final bool compact;

  /// 脏态比较基准（**服务端当前值**）。null ⇒ 等同 [initial]。
  ///
  /// ★ 为什么要和 [initial] 分开：卡片展开区被回收重建后，要用 controller 里的草稿
  ///   把输入框填回来（所以 `initial` = 草稿值），但「修改」按钮该不该亮必须拿
  ///   **服务端值**比（否则草稿自己跟自己相等 ⇒ 按钮永远置灰、提交不了）。
  final int? baseline;

  final String? unit;

  /// true ⇒ 显示「不限」快捷按钮（把输入框填 0）。
  final bool zeroMeansUnlimited;

  /// 值变化回调（每次输入/切换都会带出**当前值**）。
  ///
  /// ★ 卡片展开区必须靠它把草稿写进 controller —— 列表会回收重建卡片，
  ///   只靠组件内部 state 的话滚出去再滚回来输入就没了（清单 6.2 第 5 条）。
  final ValueChanged<int>? onChanged;

  /// 脏态变化回调（页面据此显示「有未保存改动」提示）。
  final void Function(bool dirty)? onDirtyChanged;

  /// 返回 true = 提交成功。入参是**整数**（空/非法按 0 处理）。
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
    // ★ 不只认 `_dirty` 标志：卡片被回收重建后，输入框由**草稿**填回、而 `_dirty`
    //   是初始 false ⇒ 只看标志会让「修改」永远置灰、草稿改完提交不了。
    final bool changed = _dirty || _value != (widget.baseline ?? widget.initial);
    final bool canSave = changed && !_busy && widget.onSave != null;
    // ★ 紧凑模式（v3 布局定稿）：半格里每一像素都要省 —— label 88→38、按钮内边距减半。
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
                suffixStyle: TextStyle(fontSize: 10, color: cs.outline),
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

/// 分享率上限：模式 chip（跟随全局 / 单种子 / 不限）+ 数值。
///
/// 语义沿用控制器 `setShareLimitsOf` 的约定：**-2 = 跟随全局，-1 = 不限，≥0 = 具体值**。
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

  /// 初值：-2 跟随全局 / -1 不限 / ≥0 具体值。
  final double initial;

  /// 紧凑模式（概览 Tab v3 布局定稿）：3 个模式 chip 收成**一个循环按钮**，
  /// 与另一项并排成一格（半格宽约 163dp）也放得下（10.5 排布规则第 3 条）。
  final bool compact;

  /// 脏态比较基准（**服务端当前值**）。null ⇒ 等同 [initial]。
  /// 理由同 [EditNumberField.baseline]。
  final double? baseline;

  /// 值变化回调（带出**语义值**：-2 / -1 / ≥0）。卡片展开区靠它存草稿。
  final ValueChanged<double>? onChanged;

  /// 脏态变化回调。
  final void Function(bool dirty)? onDirtyChanged;

  /// 返回 true = 提交成功。入参是**语义值**（-2/-1/≥0）。
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
      // 失败时组件内部保留用户输入（草稿不丢），由调用方的 toast 负责说明。
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
            child: Text(widget.label, style: const TextStyle(fontSize: 11)),
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
                          style: const TextStyle(fontSize: 10),
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
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      hintText: '2.00',
                      hintStyle: const TextStyle(fontSize: 11),
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
                textStyle: const TextStyle(fontSize: 11),
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

  /// 紧凑模式布局：`[label 38][数值][模式（点击循环）][修改]`。
  ///
  /// ★ 3 个模式 chip 在半格约 163dp 里放不下 ⇒ 收成一个**循环按钮**；
  ///   非「单种子」模式下数值框不渲染（是模式名而非数值），把空间让给按钮。
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
              style: const TextStyle(fontSize: 9.5),
            ),
          ),
          Expanded(
            child: _mode == _RatioMode.custom
                ? TextField(
                    controller: _c,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 10),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 6),
                      hintText: '2.00',
                      hintStyle: const TextStyle(fontSize: 10),
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
                textStyle: const TextStyle(fontSize: 9),
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
                textStyle: const TextStyle(fontSize: 10),
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

  /// 当前模式短名（紧凑模式下模式按钮的文案）。
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

  /// 循环切换模式（紧凑模式没有 3 个 chip，点一下换下一个）。
  void _cycleMode() {
    final int i = _RatioMode.values.indexOf(_mode);
    setState(() {
      _mode = _RatioMode.values[(i + 1) % _RatioMode.values.length];
    });
    widget.onChanged?.call(_value);
    widget.onDirtyChanged?.call(_dirty);
  }
}

/// 开关行：**点即生效**（不跟其它改动一起批量保存 —— 点了没反应会让用户困惑）。
///
/// ★ 失败会把开关**弹回原位**（乐观更新 + 回滚）。
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

  /// 返回 true = 成功；false/null ⇒ 开关弹回。
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
      // ★ 失败回弹：不回弹会出现"开关开着但实际没生效"的假象。
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
            child: Text(widget.label, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: widget.subtitle == null
                ? const SizedBox.shrink()
                : Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
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

/// 紧凑开关 chip：**一行并排 4 个**也放得下（概览 Tab v3 布局定稿的开关组）。
///
/// ★ 坑（10.5 实现要点 1）：`Transform.scale` **只缩视觉、不缩布局** ——
///   Switch 的 `shrinkWrap` 布局宽仍有约 59dp，一行 4 个时文字会被挤成单字截断。
///   必须用 `SizedBox(26×15) + FittedBox(child: Switch)` 才能真正压掉布局尺寸。
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

  /// 返回 true = 成功；false/null ⇒ 开关弹回。
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
    // ★ 提交期间忽略服务端回值 ⇒ 防「点即生效被 3 秒轮询打回」看起来像失败（B2）。
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
      // ★ 失败回弹：不回弹会出现"开关开着但实际没生效"的假象。
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
              fontSize: 8,
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

/// B 类 · 只读值 + 「修改」按钮（长文本/多选走弹窗确认）。
class EditActionRow extends StatelessWidget {
  const EditActionRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;

  /// 点「修改」→ 由调用方弹窗。
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
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(S.editModify),
            ),
          ),
        ],
      ),
    );
  }
}

/// 标签编辑器：chip 组（× 删）+ 输入框（回车/加号添加）+ 候选标签。
class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.tags,
    this.candidates = const <String>[],
    this.onChanged,
  });

  final List<String> tags;
  final List<String> candidates;

  /// 每次增删都回调（调用方写草稿，**不发请求**）。
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
    // 只在外部标签集真的变了才覆盖（例如提交成功后刷新）。
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
                label: Text(t, style: const TextStyle(fontSize: 10)),
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
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  hintText: S.tagInputHint,
                  hintStyle: const TextStyle(fontSize: 11),
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
                  label: Text(t, style: const TextStyle(fontSize: 10)),
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

/// 编辑弹窗集合（B 类：长文本 / 下拉 / 标签这类"点修改才弹"）。
class EditDialogs {
  EditDialogs._();

  /// 通用文本输入弹窗（重命名、新建分类等）。
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
        title: Text(title, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            hintText: hint,
            labelStyle: const TextStyle(fontSize: 11),
            hintStyle: const TextStyle(fontSize: 11),
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

  /// 保存路径弹窗：文本框 + 「是否同时移动文件」开关。
  ///
  /// ★ TR 的 `torrent-set-location` 用 `move` 决定"连数据一起搬"还是"只改指向"；
  ///   qB 的 `setLocation` **恒移动** ⇒ [askMove] = false 时弹窗里给出说明而不是开关。
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
        title: Text(S.editPathTitle, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: c,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                labelText: S.fieldPath,
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            // 改路径是高风险操作（搬错 = 种子全红）⇒ 必须显式告知。
            Text(
              askMove ? S.editPathMoveHint : S.editPathQbHint,
              style: const TextStyle(fontSize: 10, color: Colors.deepOrange),
            ),
            if (askMove)
              StatefulBuilder(
                builder: (BuildContext ctx2, StateSetter set) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(S.editPathMove,
                      style: const TextStyle(fontSize: 11)),
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

  /// 分类下拉（已有分类 + 可新建）；TR 无分类 ⇒ 调用方别调。
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
        title: Text(S.editCategoryTitle, style: const TextStyle(fontSize: 14)),
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
                        style: const TextStyle(fontSize: 10),
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
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: S.editCategoryNew,
                  labelStyle: const TextStyle(fontSize: 11),
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

  /// 标签弹窗（chip 编辑器）。返回 [TagEditResult]（含"追加/替换"标志）。
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
        title: Text(S.editTagsTitle, style: const TextStyle(fontSize: 14)),
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
                        style: const TextStyle(fontSize: 11)),
                    subtitle: Text(S.editTagsAppendHint,
                        style: const TextStyle(fontSize: 9)),
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

/// 路径弹窗结果。
class PathEditResult {
  const PathEditResult(this.path, {required this.move});

  final String path;

  /// 是否连数据一起搬（qB 恒为 true）。
  final bool move;
}

/// 标签弹窗结果：标签集 + 「追加还是整体替换」。
///
/// ★ 批量面板默认**追加**（[append] = true）：批量选中的种子标签各不相同，
///   直接整体替换会把它们抹成一样 —— 这是批量编辑最容易出的事故。
class TagEditResult {
  const TagEditResult(this.tags, {this.append = false});

  final List<String> tags;

  /// true = 只往现有标签里加，不删原有标签。
  final bool append;
}

/// v3 紧凑排布的**判据**（概览 Tab 与卡片展开区共用）。
///
/// ★ 审查台账 B3：窄屏 / 大字体下两列会挤（半格 label 仅 50dp）⇒ **回退单列**。
///   判据：可用宽度 < 360dp 或字体缩放 > 1.15。
class EditLayout {
  EditLayout._();

  /// 两列 / 2×2 / 同行 chip 是否可用。
  static bool gridOkOf(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return mq.size.width >= 360 && mq.textScaler.scale(1) <= 1.15;
  }
}

/// v3 **两列只读网格**（概览 Tab 与卡片展开区信息段共用，10.5 排布规则第 1 条）。
///
/// - [fullRows]：先渲染的**独占行** —— 长内容（内容路径这类）走这里（规则第 2 条）；
/// - [pairs]：之后按**两两一行**排的只读短值；奇数项时末格留空；
/// - [EditLayout.gridOkOf] 为假时**全部回退单列**，用 88dp label + 11 号字
///   （与详情页 `_kv` 同口径 —— 即 B3 要求的回退形态）。
class ReadonlyKvGrid extends StatelessWidget {
  const ReadonlyKvGrid({
    super.key,
    this.fullRows = const <List<String>>[],
    this.pairs = const <List<String>>[],
    this.valueSize = 10.5,
  });

  /// 每项 = `[label, value]`，独占整行（长值）。
  final List<List<String>> fullRows;

  /// 每项 = `[label, value]`，两两排一行（短值）。
  final List<List<String>> pairs;

  /// 两列模式下的值字号（展开区卡片更小，可调小）。
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    /// 半格：label 50 / 9 号，值 [valueSize] 号，长值走省略号。
    Widget halfCell(String k, String v) => Row(
          children: <Widget>[
            SizedBox(
              width: 50,
              child: Text(
                k,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
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

    /// 整行：label 88 / 11 号 + 可选中的值（与详情页 `_kv` 完全一致）。
    Widget fullCell(String k, String v) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 88,
              child: Text(k, style: const TextStyle(fontSize: 11)),
            ),
            Expanded(
              child: SelectableText(v, style: const TextStyle(fontSize: 11)),
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

/// **分区卡片**：给展开区 / 详情页的每一栏目一个**可见边界**。
///
/// ★ 2026-09-24 用户要求「每个栏目需要有边界感，增强可读性」——原来各段只用
///   `Divider` + 10 号小标题平铺，在彩色壁纸下糊成一片；改成圆角卡片
///   （细边框 + 半透明淡底 + 内边距 + 左侧色条标题），每段自成一块。
/// ★ 颜色一律取 `ColorScheme`（主题 / 壁纸 / 深浅色都会变），不硬编码。
class EditSectionCard extends StatelessWidget {
  const EditSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.dense = false,
  });

  /// 栏目名（如「限速与分享」）。
  final String title;

  final Widget child;

  /// 紧凑形态（卡片展开区用）：内边距与字号更小。
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
