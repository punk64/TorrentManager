import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/torrent_controller.dart';
import '../data/models/torrent.dart';
import '../data/server_capabilities.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import 'bottom_panel.dart';
import 'torrent_edit_fields.dart';

/// 第 67 轮 · 批量编辑面板（清单 3.2）。
///
/// ★ 与详情页**共用** `torrent_edit_fields.dart` 的组件，只是草稿 key 固定用
///   [TorrentEditSheet.kBatchKey]（批量面板没有单个 hash，不能与单项草稿混淆）。
///
/// ★ 三个批量特有的设计：
///   1. **标签默认追加**（整体替换会把各不相同的标签抹成一样 ⇒ 批量事故高发）；
///   2. **按服务器能力裁剪**：TR 隐藏分类 / 强制做种 / 超级做种；
///      「顺序下载」按**版本**显示（TR 4.1 才有，见 V6），不再按服务器类型一刀切；
///   3. **部分失败汇总**：逐种子串行提交，结束时给出「成功 N / 失败 M」并列失败种子名。
///      （整批一个请求时，只要有一个失败整体就回滚，用户完全不知道哪些成功了。）
class TorrentEditSheet {
  TorrentEditSheet._();

  /// 批量编辑的草稿 key（与单项 hash 区分开）。
  static const String kBatchKey = '__batch__';

  /// 打开面板；返回 true = 有改动被提交过（调用方决定是否刷新）。
  static Future<bool> show(List<String> hashes) async {
    if (hashes.isEmpty) return false;
    final bool? done = await BottomPanel.show<bool>(
      title: S.batchEditTitle(hashes.length),
      heightFactor: 0.82,
      child: _BatchEditBody(hashes: hashes),
    );
    return done ?? false;
  }
}

class _BatchEditBody extends StatefulWidget {
  const _BatchEditBody({required this.hashes});

  final List<String> hashes;

  @override
  State<_BatchEditBody> createState() => _BatchEditBodyState();
}

class _BatchEditBodyState extends State<_BatchEditBody> {
  final TorrentController _ctrl = Get.find<TorrentController>();

  String? _category;
  List<String>? _tags;
  bool _appendTags = true;
  int? _dlKb;
  int? _upKb;
  PathEditResult? _path;
  bool? _forceStart;
  bool? _sequential;
  bool? _firstLast;
  bool? _superSeeding;

  bool _submitting = false;
  String? _result;

  List<Torrent> get _picked => _ctrl.items
      .where((Torrent t) => widget.hashes.contains(t.hash))
      .toList();

  int get _opCount {
    int n = 0;
    if (_category != null) n++;
    if (_tags != null) n++;
    if (_dlKb != null) n++;
    if (_upKb != null) n++;
    if (_path != null) n++;
    if (_forceStart != null) n++;
    if (_sequential != null) n++;
    if (_firstLast != null) n++;
    if (_superSeeding != null) n++;
    return n;
  }

  Future<void> _pickCategory() async {
    final List<String> cats =
        _ctrl.facets(FilterDim.category).map((FacetEntry e) => e.value).toList();
    final String? v = await EditDialogs.category(
      context,
      initial: '',
      candidates: cats,
    );
    if (v == null) return;
    setState(() => _category = v);
  }

  Future<void> _pickTags() async {
    final Set<String> cand = <String>{};
    for (final Torrent t in _picked) {
      cand.addAll(t.tagList);
    }
    final TagEditResult? r = await EditDialogs.tags(
      context,
      initial: <String>[],
      candidates: cand.toList(),
      showAppendSwitch: true,
    );
    if (r == null) return;
    setState(() {
      _tags = r.tags;
      _appendTags = r.append;
    });
  }

  Future<void> _pickPath() async {
    final bool isQb = _ctrl.capabilities.isQb;
    final String initial = _picked.isNotEmpty
        ? (_picked.first.savePath ?? '')
        : '';
    final PathEditResult? r = await EditDialogs.path(
      context,
      initial: initial,
      // TR 的 set-location 有 move 参数可选；qB 恒移动 ⇒ 不显示开关，只给说明。
      askMove: !isQb,
    );
    if (r == null) return;
    setState(() => _path = r);
  }

  Future<void> _submit() async {
    if (_submitting || _opCount == 0) return;
    setState(() => _submitting = true);
    AppLog.instance.act(
        '批量编辑', '提交 $_opCount 项 × ${widget.hashes.length} 个种子');

    int ok = 0;
    final List<String> failed = <String>[];
    String? lastErr;

    for (final String h in widget.hashes) {
      final String name = _nameOf(h);
      try {
        if (_category != null) {
          await _ctrl.setCategoryOf(<String>[h], _category!);
          _throwIfFailed();
        }
        if (_tags != null) {
          await _ctrl.setTagsOf(<String>[h], _tags!, append: _appendTags);
          _throwIfFailed();
        }
        if (_dlKb != null || _upKb != null) {
          await _ctrl.setLimitsOf(<String>[h], dlKb: _dlKb, upKb: _upKb);
          _throwIfFailed();
        }
        if (_path != null) {
          await _ctrl.setLocationOf(<String>[h], _path!.path,
              move: _path!.move);
          _throwIfFailed();
        }
        if (_forceStart != null) {
          await _ctrl.setForceStartOf(<String>[h], _forceStart!);
          _throwIfFailed();
        }
        if (_sequential != null) {
          await _ctrl.toggleSequentialOf(<String>[h], target: _sequential!);
          _throwIfFailed();
        }
        if (_firstLast != null) {
          await _ctrl.toggleFirstLastPrioOf(<String>[h], target: _firstLast!);
          _throwIfFailed();
        }
        if (_superSeeding != null) {
          await _ctrl.setSuperSeedingOf(<String>[h], _superSeeding!);
          _throwIfFailed();
        }
        ok++;
      } catch (e) {
        lastErr = e is _OpError ? e.message : Formatter.safeErr(e);
        failed.add(name);
      }
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = failed.isEmpty
          ? S.batchDone(ok, 0)
          : '${S.batchDone(ok, failed.length)}'
              ' · ${S.batchFailList}${failed.take(5).join('、')}'
              '${failed.length > 5 ? ' …' : ''}'
              '${lastErr == null ? '' : '（$lastErr）'}';
    });
    // 定点刷新：qB 有时返回成功但状态延迟 ⇒ 延迟一点再拉一次。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _ctrl.refresh();
  }

  /// 每个编辑方法内部都已吞掉异常并置 `lastActionOk=false`
  /// ⇒ 这里把它翻成异常，好让外层 for 循环统一收集失败种子。
  void _throwIfFailed() {
    if (_ctrl.lastActionOk.value == false) {
      throw _OpError(_ctrl.error.value ?? S.execFailed);
    }
  }

  String _nameOf(String hash) {
    for (final Torrent t in _ctrl.items) {
      if (t.hash == hash) return t.name;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final CapabilitySet cap = _ctrl.capabilities;
    final bool isQb = cap.isQb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (isQb && cap.category)
                    EditActionRow(
                      label: S.fieldCategory,
                      value: _category ?? S.batchKeepUnchanged,
                      onTap: _submitting ? null : _pickCategory,
                    ),
                  EditActionRow(
                    label: S.fieldTags,
                    value: _tags == null
                        ? S.batchKeepUnchanged
                        : '${_tags!.isEmpty ? S.editCategoryNone : _tags!.join(', ')}'
                            '（${_appendTags ? S.editTagsAppend : S.ratioModeCustom}）',
                    onTap: _submitting ? null : _pickTags,
                  ),
                  EditNumberField(
                    label: S.fieldDlLimit,
                    initial: 0,
                    unit: 'KB/s',
                    zeroMeansUnlimited: true,
                    onSave: _submitting
                        ? null
                        : (int v) async {
                            setState(() => _dlKb = v);
                            return true;
                          },
                  ),
                  EditNumberField(
                    label: S.fieldUpLimit,
                    initial: 0,
                    unit: 'KB/s',
                    zeroMeansUnlimited: true,
                    onSave: _submitting
                        ? null
                        : (int v) async {
                            setState(() => _upKb = v);
                            return true;
                          },
                  ),
                  EditActionRow(
                    label: S.fieldPath,
                    value: _path?.path ?? S.batchKeepUnchanged,
                    onTap: _submitting ? null : _pickPath,
                  ),

                  const Divider(height: 16),
                  Text(S.editSectionSwitches,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  // ★ 批量里的开关是「待提交」，不是点即生效：
                  //   qB 的 toggle 是整批翻转，逐个提交才能保证对齐目标值。
                  _batchSwitch(S.swForceStart, _forceStart, cap.forceStart,
                      (bool v) => setState(() => _forceStart = v)),
                  _batchSwitch(S.swSequential, _sequential, cap.sequentialDownload,
                      (bool v) => setState(() => _sequential = v)),
                  _batchSwitch(S.swFirstLast, _firstLast, isQb,
                      (bool v) => setState(() => _firstLast = v)),
                  _batchSwitch(S.swSuperSeeding, _superSeeding, cap.superSeeding,
                      (bool v) => setState(() => _superSeeding = v)),
                ],
              ),
            ),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _result!,
              style: TextStyle(
                fontSize: 11,
                color: _result!.contains('失败 0') ? cs.primary : cs.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(S.cancel,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.check, size: AppTheme.iconSize),
                  label: Text(
                    _opCount == 0 ? S.batchNothing : '${S.batchSubmit}（$_opCount）',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: (_submitting || _opCount == 0) ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batchSwitch(
    String label,
    bool? value,
    bool supported,
    void Function(bool) onSet,
  ) {
    if (!supported) return const SizedBox.shrink();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 11)),
      subtitle: Text(
        value == null ? S.batchKeepUnchanged : (value ? S.yes : S.no),
        style: const TextStyle(fontSize: 9),
      ),
      value: value ?? false,
      onChanged: _submitting ? null : onSet,
    );
  }
}

/// 批量提交中的单点失败（把 controller 的 lastActionOk=false 转成异常，
/// 好让 for 循环的 try/catch 统一收集）。
class _OpError implements Exception {
  _OpError(this.message);

  final String message;
}
