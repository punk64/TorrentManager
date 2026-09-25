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
import '../app/adaptive.dart';

class TorrentEditSheet {
  TorrentEditSheet._();

  static const String kBatchKey = '__batch__';

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

    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _ctrl.refresh();
  }

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
      padding: EdgeInsets.fromLTRB(af(context, 14), 0, af(context, 14), af(context, 14)),
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
                      style: TextStyle(fontSize: af(context, 11), color: cs.onSurfaceVariant)),

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
            SizedBox(height: af(context, 8)),
            Text(
              _result!,
              style: TextStyle(
                fontSize: af(context, 11),
                color: _result!.contains('失败 0') ? cs.primary : cs.error,
              ),
            ),
          ],
          SizedBox(height: af(context, 10)),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(S.cancel,
                      style: TextStyle(fontSize: af(context, 12))),
                ),
              ),
              SizedBox(width: af(context, 10)),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: _submitting
                      ? SizedBox(
                          width: af(context, 14),
                          height: af(context, 14),
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.check, size: AppTheme.iconSize),
                  label: Text(
                    _opCount == 0 ? S.batchNothing : '${S.batchSubmit}（$_opCount）',
                    style: TextStyle(fontSize: af(context, 12)),
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
      title: Text(label, style: TextStyle(fontSize: af(context, 11))),
      subtitle: Text(
        value == null ? S.batchKeepUnchanged : (value ? S.yes : S.no),
        style: TextStyle(fontSize: af(context, 9)),
      ),
      value: value ?? false,
      onChanged: _submitting ? null : onSet,
    );
  }
}

class _OpError implements Exception {
  _OpError(this.message);

  final String message;
}
