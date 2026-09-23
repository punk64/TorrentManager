import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/theme.dart';



import '../controllers/server_controller.dart';
import '../utils/app_log.dart';
import '../utils/crypto_box.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';













class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  bool _busy = false;

  
  
  
  
  
  Future<bool> _confirmSensitiveExport(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('导出内容含敏感信息', style: TextStyle(fontSize: 15)),
        content: const Text(
          '这份 JSON 含服务器地址、端口与用户名（密码与会话已在导出时剔除）。\n\n'
          '复制后内容会进入系统剪贴板，其它应用与剪贴板历史工具都可能读到。'
          '请只粘贴到可信位置，用完后及时清空剪贴板。',
          style: TextStyle(fontSize: 12),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('仍要复制'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ServerController sc = Get.find<ServerController>();
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复', style: TextStyle(fontSize: 15)),
      ),
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              
              
              
              
              
              const Text(
                '本构建为纯本地版：备份保存在本机，'
                '如需迁移到其他设备请使用「导出 / 导入 JSON」。',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                sc.backupAt.value == null
                    ? '暂无本地备份'
                    : '最近备份：${Formatter.setDate(sc.backupAt.value!.millisecondsSinceEpoch ~/ 1000)}',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 10),

              
              
              
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      
                      
                      sc.backupDir.value == null
                          ? '备份位置：应用私有目录（未指定文件夹时的默认位置）'
                          : '备份文件夹：${sc.backupDir.value}'
                              '（写入失败会自动改存应用私有目录）',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('选择', style: TextStyle(fontSize: 11)),
                    onPressed: _busy ? null : () => sc.pickBackupDir(),
                  ),
                ],
              ),
              
              const Text(
                '备份文件已加密（AES-256-GCM，密钥由本机 Keystore 托管），'
                '因此只能在本机恢复；换设备请用「导出 / 导入 JSON」。',
                style: TextStyle(fontSize: 10),
              ),

              const SizedBox(height: 10),
              Expanded(
                child: sc.servers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Image.asset('assets/images/empty.webp', width: 80),
                            const SizedBox(height: 10),
                            const Text('尚未配置服务器',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: sc.servers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int i) {
                          final s = sc.servers[i];
                          return ListTile(
                            dense: true,
                            leading: Image.asset(
                              s.isQbittorrent
                                  ? 'assets/images/qbittorrent.png'
                                  : 'assets/images/transmission.png',
                              width: 26,
                              height: 26,
                            ),
                            title: Text(s.name, style: const TextStyle(fontSize: 12)),
                            subtitle: Text(
                              '${s.type} · ${s.displayAddress}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),

              
              
              
              
              
              
              
              
              
              
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save, size: AppTheme.iconSize),
                  label: Text(_busy ? S.fieldUpdating : '保存备份到本机',
                      style: const TextStyle(fontSize: 12)),
                  onPressed: (_busy || sc.servers.isEmpty)
                      ? null
                      : () => _run(() async {
                            final String path = await sc.saveBackup();
                            Formatter.showToast(
                                '${S.bkExportOk}'
                                '（${sc.servers.length} 个服务器）\n'
                                '${_shortPath(path)}');
                          }),
                ),
              ),
              const SizedBox(height: 8),
              
              
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.drive_file_move_outline,
                      size: AppTheme.iconSize),
                  label: const Text('导出备份副本到…',
                      style: TextStyle(fontSize: 12)),
                  onPressed: (_busy || sc.servers.isEmpty)
                      ? null
                      : () => _run(() async {
                            final String? out = await sc.exportBackupCopy();
                            if (out == null) return;
                            Formatter.showToast('${S.bkExportOk}\n${_shortPath(out)}');
                          }),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restore, size: AppTheme.iconSize),
                  label: const Text('从本机备份恢复',
                      style: TextStyle(fontSize: 12)),
                  onPressed: _busy
                      ? null
                      
                      
                      
                      : () => _run(() async {
                            final int n = await sc.restoreBackup();
                            Formatter.showToast(
                              n == 0
                                  ? '${S.bkRestoreFail}未发现新的服务器'
                                  : '${S.bkRestoreOk}$n',
                            );
                          }),
                ),
              ),
              const SizedBox(height: 8),
              
              
              
              
              
              
              Text(S.bkPortableHint,
                  style: const TextStyle(fontSize: 10, height: 1.4)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.enhanced_encryption,
                      size: AppTheme.iconSize),
                  label: Text(S.bkPortableExport,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: (_busy || sc.servers.isEmpty)
                      ? null
                      : () => _run(() async {
                            final String? p = await _askPassphrase(
                              title: S.bkPortableExportTitle,
                              body: S.bkPortableExportBody,
                              withConfirm: true,
                            );
                            if (p == null) return;
                            final String? out =
                                await sc.exportPortableBackup(p);
                            if (out == null) return;
                            Formatter.showToast(
                                '${S.bkPortableExportOk}\n${_shortPath(out)}');
                          }),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.lock_open, size: AppTheme.iconSize),
                  label: Text(S.bkPortableImport,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final PickedTextFile? f =
                                await FileExport.pickText();
                            if (f == null) return;
                            
                            if (!CryptoBox.isPortableEnvelope(f.content)) {
                              throw CryptoBoxException(S.bkPortableNotPortable);
                            }
                            if (!mounted) return;
                            final String? p = await _askPassphrase(
                              title: S.bkPortableImportTitle,
                              body: S.bkPortableImportBody,
                              withConfirm: false,
                            );
                            if (p == null) return;
                            final int n =
                                await sc.importPortableBackup(f.content, p);
                            Formatter.showToast(S.bkPortableImportOk(n));
                          }),
                ),
              ),
              const SizedBox(height: 8),

              
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share, size: AppTheme.iconSize),
                      label: const Text('导出 JSON',
                          style: TextStyle(fontSize: 11)),
                      onPressed: sc.servers.isEmpty
                          ? null
                          : () async {
                              
                              
                              
                              
                              if (!await _confirmSensitiveExport(context)) {
                                return;
                              }
                              await Clipboard.setData(
                                ClipboardData(text: sc.exportJson()),
                              );
                              Formatter.showToast(S.bkJsonExportNote);
                              AppLog.instance.op(
                                  '导出服务器 JSON 到剪贴板：'
                                  '${sc.servers.length} 台（不含密码 / SID）');
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: AppTheme.iconSize),
                      label: const Text('导入 JSON',
                          style: TextStyle(fontSize: 11)),
                      onPressed: _busy ? null : _importDialog,
                    ),
                  ),
                ],
              ),
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  
  
  

  
  
  
  
  
  String _shortPath(String path) {
    final List<String> seg = path.split(RegExp(r'[/\\]'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (seg.length <= 2) return path;
    return '…/${seg.sublist(seg.length - 2).join('/')}';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      
      Formatter.showToast(
        e is CryptoBoxException ? e.message : '${S.execFailed}: ${Formatter.safeErr(e)}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  
  
  
  
  Future<String?> _askPassphrase({
    required String title,
    required String body,
    required bool withConfirm,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _PassphraseDialog(
        title: title,
        body: body,
        withConfirm: withConfirm,
      ),
    );
  }

  Future<void> _importDialog() async {
    final TextEditingController input = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('导入服务器配置', style: TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              S.bkJsonImportNote,
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: input,
              maxLength: AppTheme.maxLenJson,
              buildCounter: AppTheme.noCounter,
              maxLines: 6,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                hintText: '[{"id": "...", "host": "..."}]',
                hintStyle: TextStyle(fontSize: 11),
                border: OutlineInputBorder(),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.content_paste, size: AppTheme.iconSize),
              label: const Text('从剪贴板粘贴',
                  style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final ClipboardData? d =
                    await Clipboard.getData(Clipboard.kTextPlain);
                if (d?.text != null) input.text = d!.text!;
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
      
    ).whenComplete(input.dispose);
    if (ok != true) return;
    final ServerController sc = Get.find<ServerController>();
    await _run(() async {
      final (int added, int updated) = sc.importJson(input.text);
      await sc.persist();
      Formatter.showToast('导入完成：新增 $added，更新 $updated');
    });
  }
}








class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.title,
    required this.body,
    required this.withConfirm,
  });

  final String title;
  final String body;

  
  final bool withConfirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  
  
  static const int _minLen = 6;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  
  String? get _error {
    final String p = _pass.text;
    if (p.isEmpty) return null; 
    if (p.length < _minLen) return S.bkPortableTooShort;
    if (widget.withConfirm && _confirm.text.isNotEmpty && p != _confirm.text) {
      return S.bkPortableMismatch;
    }
    return null;
  }

  bool get _canSubmit {
    final String p = _pass.text;
    if (p.length < _minLen) return false;
    if (widget.withConfirm && p != _confirm.text) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final String? err = _error;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.body,
              style: const TextStyle(fontSize: 11, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            maxLength: AppTheme.maxLenName,
            buildCounter: AppTheme.noCounter,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: S.bkPortablePassphrase,
              isDense: true,
              errorText: err,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: AppTheme.iconSize,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (widget.withConfirm) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              maxLength: AppTheme.maxLenName,
              buildCounter: AppTheme.noCounter,
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: S.bkPortableConfirm,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed:
              _canSubmit ? () => Navigator.of(context).pop(_pass.text) : null,
          child: Text(S.ok),
        ),
      ],
    );
  }
}
