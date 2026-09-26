import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../data/models/server_data.dart';
import '../utils/add_batch.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';
import '../widgets/torrent_edit_fields.dart';

class TorrentAddPage extends StatefulWidget {
  const TorrentAddPage({super.key});

  @override
  State<TorrentAddPage> createState() => _TorrentAddPageState();
}

enum _AddMode { url, file }

class _PickedFile {
  _PickedFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;

  String get key => path ?? name;

  bool get usable => path != null || bytes != null;
}

class _TorrentAddPageState extends State<TorrentAddPage> {
  final ServerController ctrl = Get.find<ServerController>();
  final TextEditingController _urls = TextEditingController();
  final TextEditingController _savepath = TextEditingController();
  final TextEditingController _category = TextEditingController();

  bool _paused = false;

  _AddMode _mode = _AddMode.url;
  final List<_PickedFile> _files = <_PickedFile>[];
  bool _busy = false;

  int _done = 0;
  int _total = 0;

  AddBatchResult? _result;

  final List<String> _categories = <String>[];
  final List<String> _tagCatalog = <String>[];
  final Set<String> _tags = <String>{};
  final TextEditingController _dlKb = TextEditingController();
  final TextEditingController _upKb = TextEditingController();
  final TextEditingController _ratioLimit = TextEditingController();
  final TextEditingController _seedTimeMin = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    final ServerData? s = ctrl.current.value;
    if (s == null || !s.isQbittorrent) return;
    try {
      final Map<String, dynamic> cats = await ctrl.qb.getCategories();
      final List<String> tags = await ctrl.qb.getTags();
      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(cats.keys.map((String k) => k.toString()));
        _tagCatalog
          ..clear()
          ..addAll(tags);
      });
    } catch (_) {
      // 目录拉取失败不阻塞添加，分类/标签仍可手输（标签选择器允许自由输入）
    }
  }

  Future<void> _pickCategory() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final String c in _categories)
              ListTile(
                dense: true,
                title: Text(c, style: TextStyle(fontSize: af(ctx, 12.5))),
                trailing:
                    c == _category.text ? Icon(Icons.check, size: af(ctx, 16)) : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _category.text = picked);
  }

  Future<void> _pickTags() async {
    final TagEditResult? r = await EditDialogs.tags(
      context,
      initial: _tags.toList(),
      candidates: _tagCatalog,
    );
    if (r == null || !mounted) return;
    setState(() {
      _tags
        ..clear()
        ..addAll(r.tags);
    });
  }

  Widget _tagRow(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: af(context, 8)),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final String t in _tags)
            InputChip(
              label: Text(t, style: TextStyle(fontSize: af(context, 10.5))),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onDeleted: _busy ? null : () => setState(() => _tags.remove(t)),
            ),
          ActionChip(
            avatar: Icon(Icons.sell_outlined,
                size: af(context, 14), color: cs.primary),
            label: Text(
              _tags.isEmpty ? S.fieldTags : '${S.fieldTags} · ${_tags.length}',
              style: TextStyle(
                  fontSize: af(context, 10.5),
                  color: _tags.isEmpty ? cs.onSurfaceVariant : cs.primary),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: _busy ? null : _pickTags,
          ),
        ],
      ),
    );
  }

  Widget _limitCell({
    required String label,
    required TextEditingController controller,
    String? unit,
    bool decimal = false,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: af(context, 9.5), color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            if (decimal)
              FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*$'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(fontSize: af(context, 10)),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            hintText: S.editUnlimited,
            hintStyle: TextStyle(fontSize: af(context, 10)),
            suffixText: unit,
            suffixStyle:
                TextStyle(fontSize: af(context, 10), color: cs.outline),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  int _intOf(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int get _dlKbOf => _intOf(_dlKb);
  int get _upKbOf => _intOf(_upKb);
  double get _ratioOf => double.tryParse(_ratioLimit.text.trim()) ?? 0;
  int get _seedOf => _intOf(_seedTimeMin);


  @override
  void dispose() {
    _urls.dispose();
    _savepath.dispose();
    _category.dispose();
    _dlKb.dispose();
    _upKb.dispose();
    _ratioLimit.dispose();
    _seedTimeMin.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['torrent'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null || res.files.isEmpty) {
      Formatter.showToast(S.pleaseSelectFile, isError: true);
      return;
    }
    int added = 0;
    setState(() {
      for (final PlatformFile f in res.files) {
        final _PickedFile item =
            _PickedFile(name: f.name, path: f.path, bytes: f.bytes);
        if (!item.usable) continue;

        if (_files.any((_PickedFile e) => e.key == item.key)) continue;
        _files.add(item);
        added++;
      }

      _result = null;
    });
    if (added == 0) {
      Formatter.showToast(S.noFileSelected, isError: true);
    }
  }

  void _removeFile(_PickedFile f) {
    setState(() {
      _files.removeWhere((_PickedFile e) => e.key == f.key);
      _result = null;
    });
  }

  void _clearFiles() {
    setState(() {
      _files.clear();
      _result = null;
    });
  }

  Future<void> _submit() async {
    final s = ctrl.current.value;
    if (s == null) {
      Formatter.showToast(S.srvSelectToAddTorrent, isError: true);
      return;
    }
    final List<String> urls =
        _mode == _AddMode.url ? parseUrlLines(_urls.text) : const <String>[];
    final List<_PickedFile> files = _mode == _AddMode.file
        ? List<_PickedFile>.unmodifiable(_files)
        : const <_PickedFile>[];
    if (urls.isEmpty && files.isEmpty) {
      Formatter.showToast(S.tNoLinkOrFile, isError: true);
      return;
    }

    final bool isQb = s.isQbittorrent;
    final String? savepath =
        _savepath.text.trim().isEmpty ? null : _savepath.text.trim();
    final String? category =
        _category.text.trim().isEmpty ? null : _category.text.trim();

    setState(() {
      _busy = true;
      _done = 0;
      _total = urls.length + files.length;
      _result = null;
    });

    final AddBatchResult r = AddBatchResult();
    try {
      for (final String u in urls) {
        try {
          if (isQb) {
            await ctrl.qb.addTorrents(
              urls: u,
              savepath: savepath,
              category: category,
              tags: _tags.isEmpty ? null : _tags.toList(),
              dlLimit: _dlKbOf > 0 ? _dlKbOf * 1024 : null,
              upLimit: _upKbOf > 0 ? _upKbOf * 1024 : null,
              ratioLimit: _ratioOf > 0 ? _ratioOf : null,
              seedingTimeLimit: _seedOf > 0 ? _seedOf : null,
              paused: _paused,
            );
          } else {
            await ctrl.tr.addTorrents(
              filename: u,
              downloadDir: savepath,
              paused: _paused,
              labels: category == null ? null : <String>[category],
            );
          }
          r.ok(u);
        } catch (e) {
          r.fail(u, Formatter.safeErr(e));
        }
        if (mounted) setState(() => _done++);
      }

      for (final _PickedFile f in files) {
        try {
          if (isQb) {
            final String? p = f.path;

            if (p == null) throw StateError(S.filePathUnavailable);
            await ctrl.qb.addTorrents(
              filePath: p,
              savepath: savepath,
              category: category,
              tags: _tags.isEmpty ? null : _tags.toList(),
              dlLimit: _dlKbOf > 0 ? _dlKbOf * 1024 : null,
              upLimit: _upKbOf > 0 ? _upKbOf * 1024 : null,
              ratioLimit: _ratioOf > 0 ? _ratioOf : null,
              seedingTimeLimit: _seedOf > 0 ? _seedOf : null,
              paused: _paused,
            );
          } else {
            final Uint8List bytes = await _readBytes(f);

            await ctrl.tr.addTorrents(
              metainfo: base64Encode(bytes),
              downloadDir: savepath,
              paused: _paused,
              labels: category == null ? null : <String>[category],
            );
          }
          r.ok(f.name);
        } catch (e) {
          r.fail(f.name, Formatter.safeErr(e));
        }
        if (mounted) setState(() => _done++);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted || r.isEmpty) return;

    if (r.allOk) {
      Formatter.showToast('${S.tAdded}${r.succeeded.length} 个');

      AppLog.instance.op(
          '${_mode == _AddMode.url ? '添加种子（链接' : '添加种子（文件'} ${r.succeeded.length} 条）：'
          '${r.succeeded.map(shortLabel).join(' / ')}',
          scope: ctrl.current.value?.logScope);
      Get.back<void>();
      return;
    }

    setState(() => _result = r);
    Formatter.showToast(
      '${S.tAddBatchPartial}：${S.tAdded}${r.succeeded.length} 个，'
      '${S.tAddFailed} ${r.failed.length} 个',
      isError: true,
    );
    AppLog.instance.op('添加种子部分失败：成功 ${r.succeeded.length} 条，'
        '失败 ${r.failed.length} 条 —— '
        '${r.failed.map((AddBatchFailure f) => '${shortLabel(f.label)}(${f.reason})').join(' / ')}',
        scope: ctrl.current.value?.logScope);
  }

  Future<Uint8List> _readBytes(_PickedFile f) async {
    final Uint8List? b = f.bytes;
    if (b != null) return b;
    final String? p = f.path;
    if (p == null) throw StateError(S.filePathUnavailable);
    return File(p).readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('添加种子', style: TextStyle(fontSize: af(context, 15))),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            af(context, 14), af(context, 14), af(context, 14), af(context, 10)),
        children: <Widget>[
          _serverPill(context),
          SizedBox(height: af(context, 10)),
          SegmentedButton<_AddMode>(
            segments: <ButtonSegment<_AddMode>>[
              ButtonSegment<_AddMode>(
                value: _AddMode.url,
                icon: Icon(Icons.add_link, size: AppTheme.iconSize),
                label: Text('种子链接', style: TextStyle(fontSize: af(context, 11))),
              ),
              ButtonSegment<_AddMode>(
                value: _AddMode.file,
                icon: Icon(Icons.upload_file, size: AppTheme.iconSize),
                label: Text('种子文件', style: TextStyle(fontSize: af(context, 11))),
              ),
            ],
            selected: <_AddMode>{_mode},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (Set<_AddMode> v) => setState(() => _mode = v.first),
          ),
          SizedBox(height: af(context, 10)),
          if (_mode == _AddMode.url)
            _urlsCard(context)
          else
            _filesCard(context),
          Obx(() {
            final bool isQb = ctrl.current.value?.isQbittorrent ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                EditSectionCard(
                  title: '目标',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _savepath,
                        maxLength: AppTheme.maxLenPath,
                        buildCounter: AppTheme.noCounter,
                        style: TextStyle(fontSize: af(context, 12)),
                        decoration: InputDecoration(
                          labelText: isQb ? '保存路径（可选）' : '下载目录（可选）',
                          labelStyle: TextStyle(fontSize: af(context, 12)),
                          helperText: S.setPickFromBelowPlain,
                          helperStyle: TextStyle(fontSize: af(context, 10)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: af(context, 8)),

                      TextField(
                        controller: _category,
                        maxLength: AppTheme.maxLenName,
                        buildCounter: AppTheme.noCounter,
                        style: TextStyle(fontSize: af(context, 12)),
                        decoration: InputDecoration(
                          labelText: isQb ? '分类（可选）' : S.addLabelOptional,
                          labelStyle: TextStyle(fontSize: af(context, 12)),
                          helperText: isQb ? S.setCategoryHelp : S.addLabelHelp,
                          helperStyle: TextStyle(fontSize: af(context, 10)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: (isQb && _categories.isNotEmpty)
                              ? IconButton(
                                  icon: Icon(Icons.arrow_drop_down,
                                      size: af(context, 20)),
                                  tooltip: S.fieldCategory,
                                  onPressed: _busy ? null : _pickCategory,
                                )
                              : null,
                        ),
                      ),

                      if (isQb) _tagRow(context),

                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _paused,
                        onChanged: _busy
                            ? null
                            : (bool v) => setState(() => _paused = v),
                        title: Text(S.addPauseAfterAdd,
                            style: TextStyle(fontSize: af(context, 12))),
                      ),
                    ],
                  ),
                ),
                if (isQb)
                  EditSectionCard(
                    title: S.editSectionLimits,
                    tail: S.setNoLimitZero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: _limitCell(
                                label: S.fieldDlLimit,
                                controller: _dlKb,
                                unit: 'KB/s',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _limitCell(
                                label: S.fieldUpLimit,
                                controller: _upKb,
                                unit: 'KB/s',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: _limitCell(
                                label: S.fieldRatioLimitShort,
                                controller: _ratioLimit,
                                decimal: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _limitCell(
                                label: S.fieldSeedingTimeLimit,
                                controller: _seedTimeMin,
                                unit: S.editMinutesUnit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),

          if (_result != null && !_result!.allOk)
            _failureCard(context, _result!),
        ],
      ),
      bottomNavigationBar: _dock(context),
    );
  }

  Widget _serverPill(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Obx(() {
      final s = ctrl.current.value;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: af(context, 11), vertical: af(context, 8)),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.cardBorder(cs)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              s != null && !s.isQbittorrent ? Icons.swap_horiz : Icons.dns,
              size: af(context, 15),
              color: cs.primary,
            ),
            SizedBox(width: af(context, 8)),
            Expanded(
              child: Text(
                s?.name ?? S.srvSelectToAddTorrent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: af(context, 12.5), fontWeight: FontWeight.w600),
              ),
            ),
            if (s != null)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: af(context, 8), vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.isQbittorrent ? 'qBittorrent' : 'Transmission',
                  style: TextStyle(
                    fontSize: af(context, 10),
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _urlsCard(BuildContext context) {
    final int count = parseUrlLines(_urls.text).length;
    return EditSectionCard(
      title: '来源',
      tail: count > 0 ? '已识别 $count 条' : null,
      child: TextField(
        controller: _urls,
        maxLength: AppTheme.maxLenUrls,
        buildCounter: AppTheme.noCounter,
        maxLines: 6,
        style: TextStyle(fontSize: af(context, 12)),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '磁力链接 / 种子链接',
          labelStyle: TextStyle(fontSize: af(context, 12)),
          hintText: 'magnet:?xt=urn:btih:...',
          helperText: S.setAddNewLineHelp,
          helperStyle: TextStyle(fontSize: af(context, 10)),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _filesCard(BuildContext context) {
    return EditSectionCard(
      title: '来源',
      tail: _files.isEmpty ? null : '已选 ${_files.length} 个',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _dropzone(context),
          if (_files.isNotEmpty) ...<Widget>[
            SizedBox(height: af(context, 8)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _clearFiles,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: af(context, 8)),
                  minimumSize: Size(0, af(context, 28)),
                ),
                child:
                    Text('清空', style: TextStyle(fontSize: af(context, 11))),
              ),
            ),
            _fileList(context),
          ],
        ],
      ),
    );
  }

  Widget _dropzone(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: _busy ? null : _pick,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: af(context, 16), horizontal: af(context, 12)),
          child: Column(
            children: <Widget>[
              Icon(Icons.upload_file,
                  size: af(context, 22), color: cs.primary),
              SizedBox(height: af(context, 5)),
              Text(
                '点击选择 .torrent 文件',
                style: TextStyle(
                  fontSize: af(context, 12),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: af(context, 2)),
              Text(
                '支持一次多选，自动去重',
                style: TextStyle(
                    fontSize: af(context, 10), color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileList(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < _files.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, thickness: 0.5, color: border),
            _fileRow(context, _files[i], i),
          ],
        ],
      ),
    );
  }

  Widget _fileRow(BuildContext context, _PickedFile f, int index) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: af(context, 5)),
      child: Row(
        children: <Widget>[
          SizedBox(width: af(context, 10)),
          Container(
            width: af(context, 17),
            height: af(context, 17),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: af(context, 10),
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          SizedBox(width: af(context, 9)),
          Expanded(
            child: Text(
              f.name,
              style: TextStyle(fontSize: af(context, 11)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: af(context, 16)),
            tooltip: S.remove,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
                width: af(context, 32), height: af(context, 32)),
            onPressed: _busy ? null : () => _removeFile(f),
          ),
          SizedBox(width: af(context, 4)),
        ],
      ),
    );
  }

  Widget _dock(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder(cs))),
      ),
      padding: EdgeInsets.fromLTRB(
          af(context, 14), af(context, 8), af(context, 14), af(context, 12)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_busy) ...<Widget>[
              LinearProgressIndicator(
                value: _total > 0 ? _done / _total : null,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
              SizedBox(height: af(context, 8)),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _busy
                    ? SizedBox(
                        width: af(context, 16),
                        height: af(context, 16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add, size: AppTheme.iconSize),
                label: Text(
                    _busy ? '${S.fieldUpdating} $_done/$_total' : '添加',
                    style: TextStyle(fontSize: af(context, 13))),
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failureCard(BuildContext context, AddBatchResult r) {
    final Color err = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(af(context, 10)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: err.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline, size: af(context, 16), color: err),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${S.tAddBatchFailList}（${r.failed.length}）',
                  style: TextStyle(
                      fontSize: af(context, 11),
                      fontWeight: FontWeight.w600,
                      color: err),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final AddBatchFailure f in r.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '· ${shortLabel(f.label)} —— ${f.reason}',
                style: TextStyle(fontSize: af(context, 10), color: err),
              ),
            ),
        ],
      ),
    );
  }
}
