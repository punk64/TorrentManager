import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_version.dart';
import '../utils/app_update.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../utils/update_check.dart';
import '../app/adaptive.dart';

enum UpdatePhase {

  checking,

  result,

  downloading,

  installing,

  failed,
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, this.initial, this.fetcher});

  final UpdateCheckResult? initial;

  final UpdateFetcher? fetcher;

  static Future<void> open(
    BuildContext context, {
    UpdateCheckResult? initial,
    UpdateFetcher? fetcher,
  }) =>
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) =>
            UpdateDialog(initial: initial, fetcher: fetcher),
      );

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdatePhase _phase = UpdatePhase.checking;
  UpdateCheckResult? _r;
  int _received = 0;
  int _total = 0;
  String? _error;
  CancelToken? _cancel;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final UpdateCheckResult? r = widget.initial;
    if (r != null) {
      _r = r;
      _phase = UpdatePhase.result;
    }
  }

  Future<void> _ensure() async {
    if (_started || _r != null) return;
    _started = true;
    final String? abi = await UpdateInstaller.deviceAbi();
    final UpdateCheckResult r =
        await UpdateChecker(fetcher: widget.fetcher, deviceAbi: abi).check();
    if (!mounted) return;
    setState(() {
      _r = r;
      _phase = UpdatePhase.result;
    });
  }

  String get _releaseUrl {
    final String? u = _r?.releaseUrl;
    if (u == null || u.isEmpty) return kReleasesUrl;
    return u;
  }

  Future<void> _openRelease() async {
    final String url = _releaseUrl;
    final bool ok = await UpdateInstaller.openUrl(url);
    if (ok || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    Formatter.showToast(S.updateUrlCopied);
  }

  Future<void> _startDownload() async {
    final UpdateAsset? apk = _r?.apk;
    if (apk == null) return;

    setState(() {
      _phase = UpdatePhase.downloading;
      _received = 0;
      _total = apk.size;
      _error = null;
    });

    _cancel = CancelToken();
    final UpdateDownloadResult res = await UpdateInstaller.download(
      apk,
      cancel: _cancel,
      onProgress: (int c, int t) {
        if (!mounted) return;
        setState(() {
          _received = c;
          if (t > 0) _total = t;
        });
      },
    );

    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _phase = UpdatePhase.failed;
        _error = res.error ?? S.updateDownloadFailed;
      });
      return;
    }
    await _install(res.path!);
  }

  Future<void> _install(String path) async {
    setState(() => _phase = UpdatePhase.installing);

    final String code = await UpdateInstaller.installApk(path);
    if (!mounted) return;

    if (code == UpdateInstallCode.ok) {

      Navigator.of(context).pop();
      return;
    }
    if (code == UpdateInstallCode.permission) {
      setState(() {
        _phase = UpdatePhase.failed;
        _error = S.updateNeedPermission;
      });
      return;
    }

    await _openRelease();
    if (!mounted) return;
    setState(() {
      _phase = UpdatePhase.failed;
      _error = S.updateNoNative;
    });
  }

  void _cancelDownload() {
    _cancel?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_r == null) {
      unawaited(Future<void>.microtask(_ensure));
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AlertDialog(
      title: Text(_title, style: TextStyle(fontSize: af(context, 14))),
      content: SingleChildScrollView(child: _body(cs)),
      actions: _actions,
    );
  }

  String get _title {
    final UpdateCheckResult? r = _r;
    switch (_phase) {
      case UpdatePhase.checking:
        return S.checkingUpdate;
      case UpdatePhase.downloading:
        return S.updateDownloading;
      case UpdatePhase.installing:
        return S.updateInstalling;
      case UpdatePhase.failed:
        return S.updateDownloadFailed;
      case UpdatePhase.result:
        if (r == null) return S.checkingUpdate;
        if (r.hasUpdate) return S.updateFoundTitle(r.latest ?? '');
        return S.noUpdate;
    }
  }

  Widget _body(ColorScheme cs) {
    final UpdateCheckResult? r = _r;

    if (_phase == UpdatePhase.checking || r == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: af(context, 8)),
        child: Center(child: SizedBox(width: af(context, 22), height: 22,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_phase == UpdatePhase.downloading) {
      final double v = _total > 0 ? _received / _total : 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: v.clamp(0.0, 1.0)),
          SizedBox(height: af(context, 8)),
          Text(
            '${Formatter.setSize(_received)} / ${Formatter.setSize(_total)}'
            '（${(v * 100).round()}%）',
            style: TextStyle(fontSize: af(context, 12)),
          ),
          const SizedBox(height: 6),
          Text(S.updateDownloadHint, style: TextStyle(fontSize: af(context, 10))),
        ],
      );
    }

    if (_phase == UpdatePhase.installing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          Center(child: SizedBox(width: af(context, 22), height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))),
          SizedBox(height: af(context, 8)),
          Text(S.updateInstallingHint, style: TextStyle(fontSize: af(context, 12))),
        ],
      );
    }

    if (_phase == UpdatePhase.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_error ?? '', style: TextStyle(fontSize: af(context, 12), height: 1.5)),
          SizedBox(height: af(context, 10)),
          _linkRow(cs),
        ],
      );
    }

    if (!r.hasUpdate) {
      final bool noPkg = r.reason != null && r.latest != null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            noPkg ? S.updateNoInstallerBody(r.latest!) : S.appVersionText(),
            style: TextStyle(fontSize: af(context, 12), height: 1.5),
          ),
          SizedBox(height: af(context, 10)),
          _linkRow(cs),
        ],
      );
    }

    final UpdateAsset? apk = r.apk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${S.appVersionText()}'
          '${apk != null && apk.size > 0 ? ' · ${Formatter.setSize(apk.size)}' : ''}',
          style: TextStyle(fontSize: af(context, 12)),
        ),
        if (apk != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(apk.name,
              style: TextStyle(fontSize: af(context, 11), fontFamily: 'monospace')),
        ],
        if (r.notes != null && r.notes!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: af(context, 10)),
          Text(S.updateNotes,
              style: TextStyle(fontSize: af(context, 11), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(_clipNotes(r.notes!),
                  style: TextStyle(fontSize: af(context, 11), height: 1.5)),
            ),
          ),
        ],
        SizedBox(height: af(context, 10)),
        _linkRow(cs),
      ],
    );
  }

  String _clipNotes(String s) {
    final String t = s.trim();
    const int max = 600;
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  Widget _linkRow(ColorScheme cs) => InkWell(
        key: const Key('update_link'),
        onTap: _openRelease,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.open_in_new, size: af(context, 13), color: cs.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _releaseUrl.replaceFirst(RegExp(r'^https?://'), ''),
                style: TextStyle(
                  fontSize: af(context, 11),
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  List<Widget> get _actions {
    final UpdateCheckResult? r = _r;

    if (_phase == UpdatePhase.checking || r == null) {
      return <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ];
    }

    if (_phase == UpdatePhase.downloading) {
      return <Widget>[
        TextButton(
          key: const Key('update_cancel'),
          onPressed: _cancelDownload,
          child: Text(S.cancel),
        ),
      ];
    }

    if (_phase == UpdatePhase.installing) {
      return <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ];
    }

    if (_phase == UpdatePhase.failed) {
      return <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        TextButton(
          key: const Key('update_action'),
          onPressed: _openRelease,
          child: Text(S.updateBrowserDownload),
        ),
        FilledButton(
          onPressed: _startDownload,
          child: Text(S.retry),
        ),
      ];
    }

    if (!r.hasUpdate) {
      return <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.ok),
        ),
      ];
    }

    return <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.updateLater),
      ),
      FilledButton(
        key: const Key('update_action'),
        onPressed: _startDownload,
        child: Text(S.updateNow),
      ),
    ];
  }
}
