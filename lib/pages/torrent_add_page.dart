import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../utils/add_batch.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';

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

  @override
  void dispose() {
    _urls.dispose();
    _savepath.dispose();
    _category.dispose();
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
        title: const Text('添加种子', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          SegmentedButton<_AddMode>(
            segments: const <ButtonSegment<_AddMode>>[
              ButtonSegment<_AddMode>(
                value: _AddMode.url,
                icon: Icon(Icons.add_link, size: AppTheme.iconSize),
                label: Text('种子链接', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment<_AddMode>(
                value: _AddMode.file,
                icon: Icon(Icons.upload_file, size: AppTheme.iconSize),
                label: Text('种子文件', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: <_AddMode>{_mode},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (Set<_AddMode> v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 14),

          if (_mode == _AddMode.url)
            TextField(
              controller: _urls,
              maxLength: AppTheme.maxLenUrls,
              buildCounter: AppTheme.noCounter,
              maxLines: 6,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                labelText: '磁力链接 / 种子链接',
                labelStyle: const TextStyle(fontSize: 12),
                hintText: 'magnet:?xt=urn:btih:...',
                helperText: S.setAddNewLineHelp,
                helperStyle: const TextStyle(fontSize: 10),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder, size: AppTheme.iconSize),
                      label: const Text('选择种子文件（可多选）',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _busy ? null : _pick,
                    ),
                    const SizedBox(width: 10),
                    Text('已选 ${_files.length} 个',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
                if (_files.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  for (final _PickedFile f in _files) _fileTile(context, f),
                ],
              ],
            ),

          const SizedBox(height: 12),

          Obx(() {
            final bool isQb = ctrl.current.value?.isQbittorrent ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _savepath,
                  maxLength: AppTheme.maxLenPath,
                  buildCounter: AppTheme.noCounter,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: isQb ? '保存路径（可选）' : '下载目录（可选）',
                    labelStyle: const TextStyle(fontSize: 12),
                    helperText: S.setPickFromBelowPlain,
                    helperStyle: const TextStyle(fontSize: 10),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _category,
                  maxLength: AppTheme.maxLenName,
                  buildCounter: AppTheme.noCounter,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: isQb ? '分类（可选）' : S.addLabelOptional,
                    labelStyle: const TextStyle(fontSize: 12),
                    helperText: isQb ? S.setCategoryHelp : S.addLabelHelp,
                    helperStyle: const TextStyle(fontSize: 10),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _paused,
                  onChanged: _busy
                      ? null
                      : (bool v) => setState(() => _paused = v),
                  title: Text(S.addPauseAfterAdd,
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            );
          }),

          if (_result != null && !_result!.allOk) ...<Widget>[
            const SizedBox(height: 14),
            _failureCard(context, _result!),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: AppTheme.iconSize),
            label: Text(
                _busy ? '${S.fieldUpdating} $_done/$_total' : '添加',
                style: const TextStyle(fontSize: 13)),
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _fileTile(BuildContext context, _PickedFile f) {
    final Color border = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 8),
            const Icon(Icons.insert_drive_file, size: AppTheme.iconSize),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                f.name,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: S.remove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: _busy ? null : () => _removeFile(f),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: err.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline, size: 16, color: err),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${S.tAddBatchFailList}（${r.failed.length}）',
                  style: TextStyle(fontSize: 11, color: err),
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
                style: TextStyle(fontSize: 10, color: err),
              ),
            ),
        ],
      ),
    );
  }
}
