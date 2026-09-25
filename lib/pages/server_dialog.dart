import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../data/models/server_data.dart';
import '../data/qbittorrent/qb_method.dart';
import '../data/transmission/tr_method.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

@visibleForTesting
QbMethod Function() qbProbeFactory = QbMethod.new;

@visibleForTesting
TrMethod Function() trProbeFactory = TrMethod.new;

Future<bool?> showServerDialog(
  BuildContext context, {
  ServerData? editing,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => _ServerFormDialog(editing: editing),
  );
}

Future<void> showServerLimitDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(S.srvLimitTitle),
      content: Text(S.srvLimitBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(S.ok),
        ),
      ],
    ),
  );
}

Future<String?> showConnectionErrorDialog(
  BuildContext context, {
  String? reason,
  String? address,
  String? raw,
}) {
  return showDialog<String?>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(S.error, style: TextStyle(fontSize: af(context, 15))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(S.srvConnFail, style: TextStyle(fontSize: af(context, 12))),
            if (reason != null && reason.isNotEmpty) ...<Widget>[
              SizedBox(height: af(context, 10)),
              Text('原因：$reason', style: TextStyle(fontSize: af(context, 12))),
            ],
            if (address != null && address.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              SelectableText('地址：$address',
                  style: TextStyle(fontSize: af(context, 12))),
            ],
            if (raw != null && raw.isNotEmpty)
              Theme(

                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
        clipBehavior: Clip.antiAlias,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: Text('详情', style: TextStyle(fontSize: af(context, 12))),
                  children: <Widget>[
                    SelectableText(
                      raw,
                      style: TextStyle(fontSize: af(context, 10)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('retry'),
          child: Text(S.retry),
        ),
      ],
    ),
  );
}

class _ParsedAddress {
  const _ParsedAddress(this.host, this.port, this.useHttps, this.hasScheme);

  final String host;

  final int? port;
  final bool useHttps;

  final bool hasScheme;
}

_ParsedAddress? _parseAddress(String input) {
  final String s = input.trim();
  if (s.isEmpty) return null;

  if (s.contains('://')) {
    final Uri? u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty) return null;
    if (!_isPlausibleHost(u.host)) return null;
    return _ParsedAddress(
      u.host,
      u.hasPort ? u.port : null,
      u.scheme.toLowerCase() == 'https',
      true,
    );
  }

  String h = s;
  int? port;
  final int slash = h.indexOf('/');
  if (slash >= 0) h = h.substring(0, slash);

  if (!h.startsWith('[') && ':'.allMatches(h).length >= 2) {
    if (!_isPlausibleHost(h)) return null;
    return _ParsedAddress(h, null, false, false);
  }

  if (!h.startsWith('[')) {
    final int colon = h.lastIndexOf(':');
    if (colon >= 0) {
      final int? parsed = int.tryParse(h.substring(colon + 1));
      if (parsed == null) return null;
      port = parsed;
      h = h.substring(0, colon);
    }
  }
  if (!_isPlausibleHost(h)) return null;
  return _ParsedAddress(h, port, false, false);
}

bool _isPlausibleHost(String h) {
  final String v = h.trim();
  if (v.isEmpty) return false;
  const List<String> schemes = <String>['http', 'https', 'ftp', 'ws', 'wss'];
  if (schemes.contains(v.toLowerCase())) return false;
  if (v.contains(' ')) return false;
  if (v.startsWith('.') || v.endsWith('.')) return false;
  return true;
}

Future<bool> confirmDeleteServer(BuildContext context, ServerData s) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(S.srvConfirmDeleteTitle, style: TextStyle(fontSize: af(context, 15))),
      content: Text('${S.srvConfirmDeleteBody}\n\n${s.name}',
          style: TextStyle(fontSize: af(context, 12))),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(S.ok),
        ),
      ],
    ),
  );
  return yes ?? false;
}

class _ServerFormDialog extends StatefulWidget {
  const _ServerFormDialog({this.editing});

  final ServerData? editing;

  @override
  State<_ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends State<_ServerFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.name ?? '');
  late final TextEditingController _host =
      TextEditingController(text: widget.editing?.host ?? '');

  late final TextEditingController _port = TextEditingController(
      text: (widget.editing?.port ??
              (widget.editing?.isTransmission == true ? 9091 : 443))
          .toString());
  late final TextEditingController _lanHost =
      TextEditingController(text: widget.editing?.lanHost ?? '');
  late final TextEditingController _lanPort = TextEditingController(
      text: (widget.editing?.lanPort)?.toString() ?? '');
  late final TextEditingController _user =
      TextEditingController(text: widget.editing?.username ?? '');
  late final TextEditingController _pass =
      TextEditingController(text: widget.editing?.password ?? '');

  late String _type = widget.editing?.type ?? 'qbittorrent';

  late bool _hideDomain = widget.editing?.hideAddress ?? true;

  late bool _hidePort = widget.editing?.hidePort ?? true;

  bool _saving = false;

  bool _saved = false;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _lanHost.dispose();
    _lanPort.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.editing != null;
  bool get _isQb => _type == 'qbittorrent';

  static const EdgeInsets _fieldPadding =
      EdgeInsets.fromLTRB(12, 10, 12, 10);

  void _autoSplitPort(String value) {
    final _ParsedAddress? p = _parseAddress(value);
    if (p == null || p.port == null) return;
    final String scheme = p.hasScheme ? (p.useHttps ? 'https://' : 'http://') : '';
    final String hostOnly = '$scheme${p.host}';
    if (hostOnly != value.trim()) {
      _host.text = hostOnly;
      _host.selection = TextSelection.collapsed(offset: _host.text.length);
    }
    if (_port.text.trim() != p.port.toString()) {
      _port.text = p.port.toString();
    }
  }

  String _draftSummary() {
    final String name = _name.text.trim();
    final String host = _host.text.trim();
    final String port = _port.text.trim();
    final String user = _user.text.trim();
    return '${name.isEmpty ? '未填' : name} · $_type'
        ' · ${host.isEmpty ? '未填' : '$host${port.isEmpty ? '' : ':$port'}'}'
        '${user.isEmpty ? '' : ' · 账号 $user'}';
  }

  Widget _typeItem(BuildContext context, String value) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool selected = value == _type;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: af(context, 8)),
      decoration: BoxDecoration(
        color: selected ? cs.primary.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: af(context, 13),
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check, size: af(context, 16), color: cs.primary)
          else
            SizedBox(width: af(context, 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop || result == true || _saved) return;
        AppLog.instance.op('取消${_isEdit ? '编辑' : '添加'}服务器（未保存）：'
            '${_draftSummary()}');
      },
      child: AlertDialog(
        title: Text(_isEdit ? S.srvEditing : S.srvAdd,
            style: TextStyle(fontSize: af(context, 15))),
      content: SizedBox(
        width: af(context, 340),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    maxLength: AppTheme.maxLenName,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    decoration: InputDecoration(
                      labelText: '名称',
                      hintText: S.srvEnterName,
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),
                    validator: (String? v) => (v == null || v.trim().isEmpty)
                        ? S.srvEnterName
                        : null,
                  ),
                  SizedBox(height: af(context, 8)),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isDense: true,
                    isExpanded: true,

                    style: TextStyle(
                      fontSize: af(context, 13),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),

                    borderRadius: BorderRadius.circular(AppTheme.radius),

                    alignment: AlignmentDirectional.centerStart,
                    itemHeight: 48,

                    icon: Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.arrow_drop_down, size: af(context, 24)),
                    ),
                    decoration: const InputDecoration(
                      labelText: '类型',
                      hintText: '选择服务器类型',
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),

                    items: <DropdownMenuItem<String>>[
                      for (final String v in <String>[
                        'qbittorrent',
                        'transmission'
                      ])
                        DropdownMenuItem<String>(
                          value: v,
                          child: _typeItem(context, v),
                        ),
                    ],
                    onChanged: (String? v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;

                        const Set<String> qbDefaults = <String>{'443', '8080'};
                        if (qbDefaults.contains(_port.text) ||
                            _port.text == '9091') {
                          _port.text = v == 'qbittorrent' ? '443' : '9091';
                        }
                      });
                    },
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _host,
                    maxLength: AppTheme.maxLenHost,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: '公网地址',
                      hintText: S.srvEnterAddress,
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),

                    onChanged: _autoSplitPort,
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return S.srvEnterAddress;
                      }
                      if (_parseAddress(v) == null) return S.srvAddrInvalid;
                      return null;
                    },
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _port,
                    maxLength: AppTheme.maxLenPort,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '公网端口',
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),
                    validator: (String? v) {
                      final int? p = int.tryParse((v ?? '').trim());
                      if (p == null || p <= 0 || p > 65535) {
                        return S.srvEnterValidNumber;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _lanHost,
                    maxLength: AppTheme.maxLenHost,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '局域网地址',
                      hintText: '可选，留空则用公网地址',
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _lanPort,
                    maxLength: AppTheme.maxLenPort,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '局域网端口',
                      hintText: '可选',
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),
                    validator: (String? v) {
                      final String t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final int? p = int.tryParse(t);
                      if (p == null || p <= 0 || p > 65535) {
                        return S.srvEnterValidNumber;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _user,
                    maxLength: AppTheme.maxLenName,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),
                    autofillHints: const <String>[AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: '账号',
                      isDense: true,
                      contentPadding: _fieldPadding,
                    ),

                    validator: (String? v) =>
                        (v ?? '').trim().isEmpty ? S.srvEnterUsername : null,
                  ),
                  SizedBox(height: af(context, 8)),
                  TextFormField(
                    controller: _pass,
                    maxLength: AppTheme.maxLenName,
                    buildCounter: AppTheme.noCounter,
                    style: TextStyle(fontSize: af(context, 13)),

                    obscureText: _obscurePassword,
                    autofillHints: const <String>[AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: '密码',
                      isDense: true,
                      contentPadding: _fieldPadding,

                      hintText: _isEdit ? S.srvPassKeepHint : null,
                      hintStyle: TextStyle(fontSize: af(context, 12)),

                      suffixIcon: Semantics(
                        label: _obscurePassword
                            ? S.srvShowPassword
                            : S.srvHidePassword,
                        button: true,
                        enabled: true,
                        child: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: AppTheme.iconSize,
                          ),
                          tooltip: _obscurePassword
                              ? S.srvShowPassword
                              : S.srvHidePassword,
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    validator: (String? v) {
                      final String t = (v ?? '').trim();
                      if (t.isNotEmpty) return null;

                      return _isEdit ? null : S.srvEnterPassword;
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(S.srvHideDomain,
                            style: TextStyle(fontSize: af(context, 13))),
                      ),
                      CupertinoSwitch(
                        value: _hideDomain,
                        onChanged: (bool v) => setState(() => _hideDomain = v),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(S.srvHidePort,
                            style: TextStyle(fontSize: af(context, 13))),
                      ),
                      CupertinoSwitch(
                        value: _hidePort,
                        onChanged: (bool v) => setState(() => _hidePort = v),
                      ),
                    ],
                  ),
                  if (_saving)
                    Padding(
                      padding: EdgeInsets.only(top: af(context, 8)),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: af(context, 14),
                            height: af(context, 14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: af(context, 8)),
                          Text('正在连接服务器…', style: TextStyle(fontSize: af(context, 11))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? S.srvSave : S.srvSaveShort),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      if (_user.text.trim().isEmpty ||
          (!_isEdit && _pass.text.trim().isEmpty)) {
        AppLog.instance.net(
          '添加服务器失败：缺少账号密码（${_isEdit ? '编辑' : '新增'}，'
          '地址 ${_host.text.trim().isEmpty ? '未填' : _host.text.trim()}）',
        );
        Formatter.showToast(S.srvCredsRequired, isError: true);
      }
      return;
    }

    final _ParsedAddress? parsed = _parseAddress(_host.text);
    if (parsed == null) {
      Formatter.showToast(S.srvAddrInvalid, isError: true);
      return;
    }

    final int fallbackPort =
        int.tryParse(_port.text.trim()) ?? (_isQb ? 443 : 9091);
    final int port = parsed.port ?? fallbackPort;
    if (parsed.port != null) _port.text = parsed.port.toString();

    final String? lanRaw =
        _lanHost.text.trim().isEmpty ? null : _lanHost.text.trim();
    final int? lanPortRaw = int.tryParse(_lanPort.text.trim());
    String? lanHost;
    int? lanPort;
    if (lanRaw != null) {
      final _ParsedAddress? lp = _parseAddress(lanRaw);
      if (lp != null && lp.host.isNotEmpty) {
        lanHost = lp.host;
        lanPort = lanPortRaw ?? lp.port ?? port;
      }
    }

    final ServerData s = ServerData(
      id: widget.editing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      type: _type,
      host: parsed.host,
      port: port,
      lanHost: lanHost,
      lanPort: lanPort,
      username: _user.text.trim().isEmpty ? null : _user.text.trim(),

      password: _pass.text.trim().isEmpty
          ? widget.editing?.password
          : _pass.text.trim(),

      useHttps: parsed.hasScheme
          ? parsed.useHttps
          : (widget.editing?.useHttps ?? true),
      hideAddress: _hideDomain,
      hidePort: _hidePort,
      group: widget.editing?.group,

      sid: widget.editing?.sid,
      sessionId: widget.editing?.sessionId,
      ratioLimit: widget.editing?.ratioLimit,
    );

    setState(() => _saving = true);

    final ServerController ctrl = Get.find<ServerController>();
    bool ok = false;
    Object? error;

    String? failReason;
    try {
      if (_isQb) {
        ok = await qbProbeFactory().updateQbServerCookie(s);
      } else {
        final TrLoginResult r = await trProbeFactory().updateTrServerCookie(s);
        ok = r.ok;
        failReason = r.reason;
      }
    } catch (e) {
      ok = false;
      error = e;
    }

    if (!mounted) return;

    if (!ok) {
      setState(() => _saving = false);

      final String? action = await showConnectionErrorDialog(
        context,
        reason: failReason ??
            (error == null ? '服务器未按预期响应' : NetError.describe(error)),
        address: s.baseUrl,
        raw: error?.toString(),
      );

      if (action == 'retry' && mounted) {
        await _save();
      }
      return;
    }

    await ctrl.updateServer(s);
    ctrl.select(s);
    if (!mounted) return;

    _saved = true;
    Navigator.of(context).pop(true);
    Formatter.showToast(
      '${_isEdit ? S.srvEdited : S.srvAdded}${s.name}',
    );

    unawaited(Get.find<TorrentController>().refresh());
  }
}
