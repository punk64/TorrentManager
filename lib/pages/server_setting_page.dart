import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../data/models/qb_ip_filter.dart';
import '../data/models/server_data.dart';
import '../data/prefs/server_prefs.dart';
import '../data/qbittorrent/qb_method.dart';
import '../utils/app_log.dart';
import '../utils/formatter.dart';
import '../widgets/ui_dialogs.dart';
import '../utils/ip_geo.dart';
import '../utils/net_error.dart';
import '../utils/i18n.dart';
import '../utils/log_text.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/path_dropdown.dart';
import '../controllers/torrent_controller.dart';
import '../app/adaptive.dart';

const int _kBanPreview = 30;

class ServerSettingPage extends StatefulWidget {
  const ServerSettingPage({super.key});

  @visibleForTesting
  static ServerPrefsApi? debugPrefsOverride;

  @override
  State<ServerSettingPage> createState() => _ServerSettingPageState();
}

class _ServerSettingPageState extends State<ServerSettingPage> {
  final ServerController ctrl = Get.find<ServerController>();

  late final ServerPrefsApi _api = _buildApi();

  ServerPrefsApi _buildApi() {
    final ServerPrefsApi? injected = ServerSettingPage.debugPrefsOverride;
    if (injected != null) return injected;
    final ServerData? s = _server ?? ctrl.current.value;
    if (s == null) {
      return QbPrefsApi(client: QbMethod(), resolve: (ServerData x) => x);
    }
    return createPrefsApi(
      server: s,
      qbClient: ctrl.clientForQb(s.id),
      trClient: ctrl.clientForTr(s.id),
      resolve: ctrl.targetFor,
    );
  }

  QbMethod? get _qb => _api.qb;

  ServerData? _server;
  bool _busy = false;

  Map<String, dynamic> _prefs = <String, dynamic>{};

  Map<String, dynamic> _ss = <String, dynamic>{};

  final Set<String> _touched = <String>{};

  bool _prefsLoaded = false;

  String? _prefsError;

  QbIpFilter? _banLoaded;

  QbIpFilter _banDraft = QbIpFilter.empty;

  bool _banTouched = false;

  bool _banShowAll = false;

  final TextEditingController _banInput = TextEditingController();

  final TextEditingController _blocklistUrl = TextEditingController();

  final Map<String, String?> _geo = <String, String?>{};

  final Set<String> _geoLoading = <String>{};

  final TextEditingController _upLimit = TextEditingController();
  final TextEditingController _dlLimit = TextEditingController();
  final TextEditingController _altUpLimit = TextEditingController();
  final TextEditingController _altDlLimit = TextEditingController();
  final TextEditingController _savePath = TextEditingController();
  final TextEditingController _tempPath = TextEditingController();
  final TextEditingController _maxActiveUp = TextEditingController();
  final TextEditingController _maxActiveDl = TextEditingController();
  final TextEditingController _maxActiveTorrents = TextEditingController();
  final TextEditingController _maxRatio = TextEditingController();
  final TextEditingController _maxSeedingTime = TextEditingController();
  final TextEditingController _maxInactiveSeedingTime = TextEditingController();
  final TextEditingController _maxConnec = TextEditingController();
  final TextEditingController _maxConnecPerTorrent = TextEditingController();
  final TextEditingController _maxUpConnec = TextEditingController();
  final TextEditingController _maxUpConnecPerTorrent = TextEditingController();

  final List<String> _categories = <String>[];
  final List<String> _tags = <String>[];
  final Set<String> _selectedCategories = <String>{};
  final Set<String> _selectedTags = <String>{};

  @override
  void initState() {
    super.initState();
    final dynamic arg = Get.arguments;
    _server = arg is ServerData ? arg : ctrl.current.value;

    final ServerData? s = _server;
    if (s != null) _api.attach(s);

    final ServerPrefsSnap? cached = s == null ? null : ctrl.prefsSnapOf(s.id);
    if (cached != null) {
      _prefs = cached.prefs;
      _ss = cached.serverState;
      _categories
        ..clear()
        ..addAll(cached.categories);
      _tags
        ..clear()
        ..addAll(cached.tags);
      _prefsLoaded = true;
      _prefsError = null;
      _applyPreferences();
    }

    unawaited(_loadPreferences());
    _loadCategoriesAndTags();
  }

  Future<bool> _ensureSession() =>
      _sessionFuture ??= _api.ensureSession();

  Future<bool>? _sessionFuture;

  void _reopenSession() {
    _sessionFuture = null;
    _api.reopenSession();
  }

  String _sessionFailReason() {
    if (_api.lastBanned) return S.srvIpBanned;
    if (_api.lastMissingCreds) return S.srvCredsMissing;
    final String? e = _api.lastError;
    return (e == null || e.isEmpty) ? S.sessionNotEstablished : e;
  }

  Future<void> _loadPreferences() async {
    if (!_isSupported || _server == null) return;
    try {
      if (!await _ensureSession()) {
        if (!mounted) return;
        final String reason = _sessionFailReason();
        setState(() {
          _prefsLoaded = false;
          _prefsError = reason;
        });
        AppLog.instance.net(LogT.sessionFail(reason),
        scope: _server?.logScope);
        return;
      }

      final Map<String, dynamic> p = await _api.read();

      final Map<String, dynamic>? ss = await _api.readServerState();
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _ss = ss ?? <String, dynamic>{};
        _prefsLoaded = true;
        _prefsError = null;
        _applyPreferences();
      });
      ctrl.putPrefsSnap(
        _server!.id,
        ServerPrefsSnap(
          prefs: _prefs,
          serverState: _ss,
          categories: _categories,
          tags: _tags,
          at: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefsLoaded = false;
        _prefsError = NetError.describe(e);
      });
      AppLog.instance.net(LogT.prefsLoadFail(NetError.describe(e)),
        scope: _server?.logScope);
    }
  }

  bool get _isSupported => _server != null;

  bool get _isQb => _api.isQb;

  String _okToast(String qbMsg) => _isQb ? qbMsg : S.editSaved;

  String _failToast(String qbMsg) =>
      _isQb ? qbMsg : '${S.execFailed}: ${Formatter.safeErr('')}';

  bool _supports(String key) => _api.supports(key);

  bool _prefBool(String key, {bool def = false}) {
    final dynamic v = _prefs[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true';
    return def;
  }

  bool _ssBool(String key, {bool def = false}) {
    final dynamic v = _ss[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    return def;
  }

  String _prefKbOf(String key) {
    if (!_prefsLoaded) return '';
    final dynamic v = _prefs[key];
    final int bytes = v is num ? v.toInt() : 0;
    return (bytes ~/ 1024).toString();
  }

  void _applyPreferences() {
    void put(String key, TextEditingController c, String value) {
      if (_touched.contains(key)) return;

      if (c.text == value) return;
      c.text = value;
    }

    put('save_path', _savePath, (_prefs['save_path'] ?? '').toString());

    put(PrefKey.blocklistUrl, _blocklistUrl,
        (_prefs[PrefKey.blocklistUrl] ?? '').toString());
    put('temp_path', _tempPath, (_prefs['temp_path'] ?? '').toString());
    put('alt_up_limit', _altUpLimit, _prefKbOf('alt_up_limit'));
    put('alt_dl_limit', _altDlLimit, _prefKbOf('alt_dl_limit'));

    put('up_limit', _upLimit, _prefKbOf('up_limit'));
    put('dl_limit', _dlLimit, _prefKbOf('dl_limit'));

    put('max_active_uploads', _maxActiveUp, _prefNumText('max_active_uploads'));
    put('max_active_downloads', _maxActiveDl,
        _prefNumText('max_active_downloads'));
    put('max_active_torrents', _maxActiveTorrents,
        _prefNumText('max_active_torrents'));

    final dynamic ratio = _prefs['max_ratio'];
    put('max_ratio', _maxRatio, _numText(ratio));
    put('max_seeding_time', _maxSeedingTime, _prefNumText('max_seeding_time'));
    put('max_inactive_seeding_time', _maxInactiveSeedingTime,
        _prefNumText('max_inactive_seeding_time'));

    put('max_connec', _maxConnec, _prefNumText('max_connec'));
    put('max_connec_per_torrent', _maxConnecPerTorrent,
        _prefNumText('max_connec_per_torrent'));
    put('max_uploads', _maxUpConnec, _prefNumText('max_uploads'));
    put('max_uploads_per_torrent', _maxUpConnecPerTorrent,
        _prefNumText('max_uploads_per_torrent'));

    _applyBanPrefs();
  }

  void _applyBanPrefs() {
    final QbIpFilter real = QbIpFilter.fromPrefs(_prefs);
    _banLoaded = real;
    if (!_banTouched) _banDraft = real;
  }

  String _prefNumText(String key) => _numText(_prefs[key]);

  int? _prefInt(String key) {
    final dynamic v = _prefs[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _numText(dynamic v) {
    if (v is! num) return '';
    final double d = v.toDouble();
    if (!d.isFinite) return '';
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    return d.toString();
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _upLimit, _dlLimit, _altUpLimit, _altDlLimit, _savePath, _tempPath,
      _maxActiveUp, _maxActiveDl, _maxActiveTorrents, _maxRatio,
      _maxSeedingTime, _maxInactiveSeedingTime, _maxConnec,
      _maxConnecPerTorrent, _maxUpConnec, _maxUpConnecPerTorrent,
      _banInput, _blocklistUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isCurrentServer {
    final ServerData? cur = ctrl.current.value;
    final ServerData? s = _server;
    return cur != null && s != null && cur.id == s.id;
  }

  Future<void> _tick() async {
    if (_busy || !_isSupported) return;

    final Future<bool>? pending = _sessionFuture;
    if (pending == null || !await pending) return;
    try {
      final Map<String, dynamic>? next = await _api.readServerState();
      if (next == null) return;
      final bool changed =
          next[PrefKey.altSpeedEnabled] != _ss[PrefKey.altSpeedEnabled];
      if (!mounted) return;
      if (_ss.isEmpty || changed) setState(() => _ss = next);

      if (_isQb && _isCurrentServer) ctrl.updateServerState(next);
    } catch (_) {
    }
  }

  Future<void> _loadCategoriesAndTags() async {
    final QbMethod? qb = _qb;
    if (qb == null) return;
    try {
      if (!await _ensureSession()) return;
      final Map<String, dynamic> cats = await qb.getCategories();
      final List<String> tags = await qb.getTags();
      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(cats.keys.map((String k) => k.toString()));
        _tags
          ..clear()
          ..addAll(tags);
      });
      final ServerData? srv = _server;
      if (srv != null) {
        ctrl.putPrefsSnap(
          srv.id,
          ServerPrefsSnap(
            prefs: _prefs,
            serverState: _ss,
            categories: _categories,
            tags: _tags,
            at: DateTime.now(),
          ),
        );
      }
    } catch (_) {
    }
  }

  Future<void> _run(
    String label,
    String okMsg,
    String failMsg,
    Future<void> Function() act, {
    VoidCallback? after,
    String? detail,
    bool refreshLimit = false,
  }) async {
    AppLog.instance.act('服务器设置', label,
        target: _server?.name, detail: detail);
    setState(() => _busy = true);
    try {
      await act();
      UiDialogs.showToast(okMsg);
      after?.call();
      await _loadCategoriesAndTags();

      await _loadPreferences();

      if (refreshLimit) {
        final ServerData? srv = _server;
        if (srv != null) unawaited(ctrl.invalidateSpeedLimit(srv.id));
      }
    } catch (e) {
      AppLog.instance.op('$label 失败：${Formatter.safeErr(e)}',
          level: 'ERROR', scope: _server?.logScope);
      UiDialogs.showToast('$failMsg ${Formatter.safeErr(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _kb(TextEditingController c) {
    final int? v = int.tryParse(c.text.trim());

    return v == null ? 0 : v * 1024;
  }

  String _kbText(TextEditingController c) {
    final String t = c.text.trim();
    return t.isEmpty ? '0' : t;
  }

  @override
  Widget build(BuildContext context) {
    final String name = _server?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(S.serverSettingsTitle(name)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh, size: AppTheme.iconSize),
            tooltip: S.fieldUpdating,

            onPressed: () async {
              AppLog.instance.act('服务器设置', L.t('AppBar[刷新]'),
                  target: _server?.name, detail: LogT.appbarRefreshDetail());

              _reopenSession();

              await _loadPreferences();
              await _loadCategoriesAndTags();
              await _tick();
            },
          ),
        ],
      ),
      body: AutoRefresh(
        onTick: _tick,
        enabled: !_busy,
        child: ListView(
          padding: EdgeInsets.only(
              top: af(context, 8), bottom: af(context, 24)),
          children: <Widget>[

            if (_server == null)
              Padding(
                padding: EdgeInsets.all(af(context, 28)),
                child: Center(
                  child: Text(S.noServer,
                      style: TextStyle(fontSize: af(context, 12))),
                ),
              ),
            if (_server != null && _prefsError != null) _prefsErrorNotice(),
            if (_server != null) ...<Widget>[
              _limitGroup(),

              if (_isQb) _categoryGroup(),
              if (_isQb) _tagGroup(),
              _savePathGroup(),
              _tempPathGroup(),
              _queueGroup(),
              _seedingGroup(),
              _connectionGroup(),
              _discoveryGroup(),
              _miscGroup(),
              _banGroup(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _limitGroup() => _group(
        icon: Icons.speed_rounded,
        title: L.t('限速设置'),
        summary: '↑ ${_kbText(_upLimit)} · ↓ ${_kbText(_dlLimit)} KB/s',
        help: '${S.setNoLimitZero}\n${S.setSwitchToEnable}',
        children: <Widget>[
          _sectionTitle(L.t('普通限速'), onChange: () => _run(
            LogT.prefChanged(L.t('全局限速')),
            _okToast(S.qbSetServerLimit),
            _failToast(S.qbSetServerLimitFail),
            () => _api.write(<String, dynamic>{
              PrefKey.upLimit: _kb(_upLimit),
              PrefKey.dlLimit: _kb(_dlLimit),
            }),
            detail: S.kbPair(_kbText(_upLimit), _kbText(_dlLimit)),
            refreshLimit: true,
          )),
          _gridRow(<Widget>[
            Expanded(
              child: _numCell(L.t('上传限速'), _upLimit,
                  prefKey: PrefKey.upLimit, unit: 'KB/S'),
            ),
            Expanded(
              child: _numCell(L.t('下载限速'), _dlLimit,
                  prefKey: PrefKey.dlLimit, unit: 'KB/S'),
            ),
          ]),
          _sectionDivider(),
          _sectionTitle(L.t('备用限速'), onChange: () => _run(
            LogT.prefChanged(L.t('备用限速')),
            _okToast(S.qbSetAltLimit),
            _failToast(S.qbSetAltLimitFail),
            () => _api.write(<String, dynamic>{
              PrefKey.altUpLimit: _kb(_altUpLimit),
              PrefKey.altDlLimit: _kb(_altDlLimit),
            }),
            detail: S.kbPair(_kbText(_altUpLimit), _kbText(_altDlLimit)),
            refreshLimit: true,
          )),
          _switchRow(
            S.setEnableAltLimit,
            _ssBool(PrefKey.altSpeedEnabled),
            (bool v) => _run(
              LogT.prefSwitch(S.setEnableAltLimit, v),
              _okToast(S.qbSetAltLimit),
              _failToast(S.qbSetAltLimitFail),
              () async {
                await _api.write(<String, dynamic>{
                  PrefKey.altSpeedEnabled: v,
                });

                _ss[PrefKey.altSpeedEnabled] = v;
                if (_isCurrentServer) {
                  ctrl.state.value.useAltSpeedLimits = v;
                  ctrl.state.refresh();
                }
              },
              refreshLimit: true,
            ),
          ),
          _gridRow(<Widget>[
            Expanded(
              child: _numCell(L.t('上传限速'), _altUpLimit,
                  prefKey: 'alt_up_limit', unit: 'KB/S'),
            ),
            Expanded(
              child: _numCell(L.t('下载限速'), _altDlLimit,
                  prefKey: 'alt_dl_limit', unit: 'KB/S'),
            ),
          ]),
        ],
      );

  Widget _sectionTitle(String text, {String? help, VoidCallback? onChange}) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          af(context, 8), af(context, 6), af(context, 8), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: af(context, 3),
                height: af(context, 12),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(af(context, 2)),
                ),
              ),
              SizedBox(width: af(context, 6)),
              Text(
                text,
                style: TextStyle(
                  fontSize: af(context, 12),
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const Spacer(),
              if (onChange != null) _pillButton(S.change, accent, onChange),
            ],
          ),
          if (help != null)
            Padding(
              padding: EdgeInsets.only(
                  left: af(context, 9), top: af(context, 2)),
              child: Text(help, style: TextStyle(fontSize: af(context, 10))),
            ),
        ],
      ),
    );
  }

  Widget _sectionDivider() => Padding(
        padding: EdgeInsets.fromLTRB(
            af(context, 8), af(context, 12), af(context, 8), 0),
        child: Divider(
          height: af(context, 1),
          thickness: af(context, 0.5),
          color:
              Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      );

  Widget _categoryGroup() => _group(
        icon: Icons.folder_open_rounded,
        title: L.t('管理分类'),
        summary: S.countLabel(_categories.length),
        help: S.setCategoryEditHelp,
        children: <Widget>[
          if (_categories.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: af(context, 16), vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: Text(L.t('未分类'), style: TextStyle(fontSize: af(context, 12))),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String c in _categories)
                FilterChip(
                  label: Text(c, style: TextStyle(fontSize: af(context, 11))),
                  selected: _selectedCategories.contains(c),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() {
                    if (!_selectedCategories.add(c)) {
                      _selectedCategories.remove(c);
                    }
                  }),
                ),
            ],
          ),
          _actionRow(
            onAdd: _addCategory,
            onDelete: _removeSelectedCategories,
          ),
        ],
      );

  Future<void> _addCategory() async {
    final String? name = await _promptText(
      title: S.add,
      label: L.t('类别名称'),
      help: S.setPickFromBelow,
    );
    if (name == null || name.trim().isEmpty) {
      if (name != null) UiDialogs.showToast(S.catNameEmpty, isError: true);
      return;
    }
    await _run(
      LogT.prefAdded(L.t('分类'), name.trim()),
      '${S.catCreatedPlain}: $name',
      S.execFailed,
      () => _qb!.createCategory(name.trim()),
      detail: LogT.countBeforeCommit(_categories.length),
    );
  }

  Future<void> _removeSelectedCategories() async {
    if (_selectedCategories.isEmpty) {
      UiDialogs.showToast(S.pleaseSelectCategory, isError: true);
      return;
    }
    final String joined = _selectedCategories.join('\n');
    await _run(
      LogT.prefRemoved(L.t('分类'), _selectedCategories.join('、')),
      '${S.catRemovedPlain}: $joined',
      S.execFailed,
      () => _qb!.removeCategories(joined),
      after: () => _selectedCategories.clear(),
      detail: LogT.countBefore(_categories.length),
    );
  }

  Widget _tagGroup() => _group(
        icon: Icons.label_outline_rounded,
        title: L.t('管理标签'),
        summary: S.countLabel(_tags.length),
        help: S.setTagDeleteHelp,
        children: <Widget>[
          if (_tags.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: af(context, 16), vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: Text(L.t('无标签'), style: TextStyle(fontSize: af(context, 12))),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String t in _tags)
                FilterChip(
                  label: Text(t, style: TextStyle(fontSize: af(context, 11))),
                  selected: _selectedTags.contains(t),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() {
                    if (!_selectedTags.add(t)) _selectedTags.remove(t);
                  }),
                ),
            ],
          ),
          _actionRow(onAdd: _addTag, onDelete: _removeSelectedTags),
        ],
      );

  Future<void> _addTag() async {
    final String? name =
        await _promptText(title: S.add, label: L.t('标签名称'), help: S.setAddNewLineHelp);
    if (name == null || name.trim().isEmpty) return;
    await _run(
      LogT.prefAdded(L.t('标签'), name.trim()),
      '${S.tagCreatedPlain}: ${name.trim()}',
      S.execFailed,
      () => _qb!.createTags(name.trim()),
      detail: LogT.countBefore(_tags.length),
    );
  }

  Future<void> _removeSelectedTags() async {
    if (_selectedTags.isEmpty) {
      UiDialogs.showToast(S.pleaseSelectTag, isError: true);
      return;
    }
    final String joined = _selectedTags.join('\n');
    await _run(
      LogT.prefRemoved(L.t('标签'), _selectedTags.join('、')),
      '${S.tagRemovedPlain}: $joined',
      S.execFailed,
      () => _qb!.deleteTags(joined),
      after: () => _selectedTags.clear(),
      detail: LogT.countBefore(_tags.length),
    );
  }

  Widget _savePathGroup() => _group(
        icon: Icons.save_outlined,
        title: L.t('默认保存路径'),
        summary: _savePath.text,
        help: _isQb ? S.setPickFromBelowNoAutoTmm : S.setPickFromBelowPlain,
        children: <Widget>[
          _pathDropdownField(L.t('默认保存路径'), _savePath),
          _changeButton(
            LogT.prefChanged(L.t('保存路径')),
            _okToast(S.qbSetSavePath),
            _failToast(S.qbSetSavePathFail),
            () => _api.write(<String, dynamic>{
              PrefKey.savePath: _savePath.text.trim(),
            }),
            detail: LogT.detailPath(_savePath.text.trim()),
          ),
        ],
      );

  Widget _tempPathGroup() => _group(
        icon: Icons.timelapse_rounded,
        title: L.t('临时保存路径'),
        summary: _onOffLabel(_prefBool('temp_path_enabled')),
        help: S.setTempPathHelp,
        children: <Widget>[

          _switchRow(
            S.setEnableTempPath,
            _prefBool('temp_path_enabled'),
            (bool v) => _run(
              LogT.prefSwitch(S.setEnableTempPath, v),
              _okToast(S.qbSetTempPath),
              _failToast(S.qbSetTempPathFail),
              () => _api.write(<String, dynamic>{PrefKey.tempPathEnabled: v}),
              after: () => _prefs['temp_path_enabled'] = v,
            ),
          ),
          _pathDropdownField(L.t('临时路径'), _tempPath),
          _changeButton(
            LogT.prefChanged(L.t('临时路径')),
            _okToast(S.qbSetTempPath),
            _failToast(S.qbSetTempPathFail),
            () => _api.write(<String, dynamic>{
              PrefKey.tempPath: _tempPath.text.trim(),
            }),
            detail: LogT.detailPath(_tempPath.text.trim()),
          ),
        ],
      );

  Widget _queueGroup() => _group(
        icon: Icons.low_priority_rounded,
        title: L.t('设置队列限制'),
        summary: _onOffLabel(_prefBool('queueing_enabled')),
        help: S.setQueueSwitchHelp,
        children: <Widget>[
          _switchRow(
            S.setEnableQueueLimit,

            _prefBool('queueing_enabled'),
            (bool v) => _run(
              LogT.prefSwitch(S.setEnableQueueLimit, v),
              _okToast(S.qbSetQueueing),
              _failToast(S.qbSetQueueingFail),
              () async {
                await _api.write(<String, dynamic>{PrefKey.queueingEnabled: v});
                _prefs['queueing_enabled'] = v;
                if (_isCurrentServer) {
                  ctrl.state.value.queueing = v;
                  ctrl.state.refresh();
                }
              },
            ),
          ),

          _gridRow(<Widget>[
            if (_supports(PrefKey.maxActiveUploads))
              Expanded(
                child: _numCell(L.t('最大活动上传数'), _maxActiveUp,
                    prefKey: PrefKey.maxActiveUploads),
              ),
            if (_supports(PrefKey.maxActiveDownloads))
              Expanded(
                child: _numCell(L.t('最大活动下载数'), _maxActiveDl,
                    prefKey: PrefKey.maxActiveDownloads),
              ),
            if (_supports(PrefKey.maxActiveTorrents))
              Expanded(
                child: _numCell(L.t('最大活动种子数'), _maxActiveTorrents,
                    prefKey: PrefKey.maxActiveTorrents),
              ),
          ]),
          _changeButton(
            LogT.prefChanged(L.t('队列限制')),
            _okToast(S.qbSetQueueing),
            _failToast(S.qbSetQueueingFail),
            () => _api.write(<String, dynamic>{
              PrefKey.maxActiveUploads: int.tryParse(_maxActiveUp.text.trim()),
              PrefKey.maxActiveDownloads:
                  int.tryParse(_maxActiveDl.text.trim()),
              if (_supports(PrefKey.maxActiveTorrents))
                PrefKey.maxActiveTorrents:
                    int.tryParse(_maxActiveTorrents.text.trim()),
            }),
            detail: S.queueDetail(
                _kbText(_maxActiveUp),
                _kbText(_maxActiveDl),
                _supports(PrefKey.maxActiveTorrents)
                    ? _kbText(_maxActiveTorrents)
                    : null),
          ),
        ],
      );

  Widget _seedingGroup() => _group(
        icon: Icons.trending_up_rounded,
        title: L.t('设置做种限制'),
        summary: L.pick('比率 ${_kbText(_maxRatio)}', 'Ratio ${_kbText(_maxRatio)}'),
        help: S.setRatioHelp,
        children: <Widget>[
          _seedingRow(L.t('最大分享比率'), _maxRatio,
              prefKey: PrefKey.maxRatio,
              enabled: _prefBool(PrefKey.maxRatioEnabled),
              onEnabledChanged: (bool v) => _run(
                LogT.prefSwitch(L.t('最大分享比率'), v),
                _okToast(S.qbSetRatio),
                _failToast(S.qbSetRatioFail),
                () => _api.write(<String, dynamic>{
                  PrefKey.maxRatioEnabled: v,
                }),
                after: () => _prefs[PrefKey.maxRatioEnabled] = v,
              )),
          if (_supports(PrefKey.maxSeedingTime))
            _seedingRow(L.t('最长做种时间'), _maxSeedingTime,
                prefKey: PrefKey.maxSeedingTime,
                unit: L.t('分'),
                enabled: _prefBool(PrefKey.maxSeedingTimeEnabled),
                onEnabledChanged: (bool v) => _run(
                  LogT.prefSwitch(L.t('最长做种时间'), v),
                  _okToast(S.qbSetRatio),
                  _failToast(S.qbSetRatioFail),
                  () => _api.write(<String, dynamic>{
                    PrefKey.maxSeedingTimeEnabled: v,
                  }),
                  after: () => _prefs[PrefKey.maxSeedingTimeEnabled] = v,
                )),
          _seedingRow(L.t('非活动做种时间'), _maxInactiveSeedingTime,
              prefKey: PrefKey.maxInactiveSeedingTime,
              unit: L.t('分'),
              enabled: _prefBool(PrefKey.maxInactiveSeedingTimeEnabled),
              onEnabledChanged: (bool v) => _run(
                LogT.prefSwitch(L.t('非活动做种时间'), v),
                _okToast(S.qbSetRatio),
                _failToast(S.qbSetRatioFail),
                () => _api.write(<String, dynamic>{
                  PrefKey.maxInactiveSeedingTimeEnabled: v,
                }),
                after: () => _prefs[PrefKey.maxInactiveSeedingTimeEnabled] = v,
              )),
          _changeButton(
            LogT.prefChanged(L.t('做种限制')),
            _okToast(S.qbSetRatio),
            _failToast(S.qbSetRatioFail),
            // 启用开关由上方开关行单独即时下发；输入为空不下发（保留服务端现值，
            // 避免 qB「-1=不限」与 TR「负值非法」语义冲突）
            () {
              final double? ratio = double.tryParse(_maxRatio.text.trim());
              final int? seedTime = _supports(PrefKey.maxSeedingTime)
                  ? int.tryParse(_maxSeedingTime.text.trim())
                  : null;
              final int? idleTime =
                  int.tryParse(_maxInactiveSeedingTime.text.trim());
              return _api.write(<String, dynamic>{
                if (ratio != null) PrefKey.maxRatio: ratio,
                if (seedTime != null) PrefKey.maxSeedingTime: seedTime,
                if (idleTime != null) PrefKey.maxInactiveSeedingTime: idleTime,
              });
            },
            detail: S.seedDetail(
                _kbText(_maxRatio),
                _kbText(_maxInactiveSeedingTime),
                _supports(PrefKey.maxSeedingTime)
                    ? _kbText(_maxSeedingTime)
                    : null),
          ),
        ],
      );

  Widget _connectionGroup() => _group(
        icon: Icons.lan_rounded,
        title: L.t('设置连接限制'),
        summary: L.pick('全局 ${_kbText(_maxConnec)} · 单种 ${_kbText(_maxConnecPerTorrent)}', 'Global ${_kbText(_maxConnec)} · per-torrent ${_kbText(_maxConnecPerTorrent)}'),
        help: S.setQueueSwitchHelp,
        children: <Widget>[
          _gridRow(<Widget>[
            Expanded(
              child: _numCell(L.t('全局最大连接数'), _maxConnec,
                  prefKey: PrefKey.maxConnec),
            ),
            Expanded(
              child: _numCell(L.t('单种最大连接数'), _maxConnecPerTorrent,
                  prefKey: PrefKey.maxConnecPerTorrent),
            ),
          ]),
          _gridRow(<Widget>[
            if (_supports(PrefKey.maxUploads))
              Expanded(
                child: _numCell(L.t('全局上传连接数'), _maxUpConnec,
                    prefKey: PrefKey.maxUploads),
              ),
            Expanded(
              child: _numCell(L.t('单种上传连接数'), _maxUpConnecPerTorrent,
                  prefKey: PrefKey.maxUploadsPerTorrent),
            ),
          ]),
          _changeButton(
            LogT.prefChanged(L.t('连接限制')),
            _okToast(S.qbSetMaxConnec),
            _failToast(S.qbSetMaxConnecFail),
            () => _api.write(<String, dynamic>{
              PrefKey.maxConnec: int.tryParse(_maxConnec.text.trim()),
              PrefKey.maxConnecPerTorrent:
                  int.tryParse(_maxConnecPerTorrent.text.trim()),
              if (_supports(PrefKey.maxUploads))
                PrefKey.maxUploads: int.tryParse(_maxUpConnec.text.trim()),
              PrefKey.maxUploadsPerTorrent:
                  int.tryParse(_maxUpConnecPerTorrent.text.trim()),
            }),
            detail: S.connDetail(
                _kbText(_maxConnec),
                _kbText(_maxConnecPerTorrent),
                _kbText(_maxUpConnecPerTorrent),
                _supports(PrefKey.maxUploads) ? _kbText(_maxUpConnec) : null),
          ),
        ],
      );

  Widget _discoveryGroup() => _group(
        icon: Icons.travel_explore_rounded,
        title: S.setDiscoveryGroup,
        summary: S.autoMgrActiveCount(_discoveryOnCount()),
        help: S.setDiscoveryHelp,
        children: <Widget>[
          _switchRow(
            S.setEnableDht,
            _prefBool(PrefKey.dht),
            (bool v) => _writeDiscovery(PrefKey.dht, v),
            sub: S.setEnableDhtSub,
          ),
          _switchRow(
            S.setEnablePex,
            _prefBool(PrefKey.pex),
            (bool v) => _writeDiscovery(PrefKey.pex, v),
            sub: S.setEnablePexSub,
          ),
          _switchRow(
            S.setEnableLsd,
            _prefBool(PrefKey.lsd),
            (bool v) => _writeDiscovery(PrefKey.lsd, v),
            sub: S.setEnableLsdSub,
          ),
          if (_supports(PrefKey.anonymousMode))
            _switchRow(
              S.setAnonymousMode,
              _prefBool(PrefKey.anonymousMode),
              (bool v) => _writeDiscovery(PrefKey.anonymousMode, v),
              sub: S.setAnonymousModeSub,
            ),
          _sectionDivider(),
          _encryptionRow(),
        ],
      );

  int _discoveryOnCount() {
    int n = 0;
    if (_prefBool(PrefKey.dht)) n++;
    if (_prefBool(PrefKey.pex)) n++;
    if (_prefBool(PrefKey.lsd)) n++;
    if (_supports(PrefKey.anonymousMode) && _prefBool(PrefKey.anonymousMode)) {
      n++;
    }
    return n;
  }

  Future<void> _writeDiscovery(String key, bool v) => _run(
        LogT.prefSwitch(L.t('网络发现'), v),
        _okToast(S.qbSetDiscovery),
        _failToast(S.qbSetDiscoveryFail),
        () => _api.write(<String, dynamic>{key: v}),
        after: () => _prefs[key] = v,
      );

  int get _encryptionValue {
    final dynamic v = _prefs[PrefKey.encryption];
    final int n = v is int
        ? v
        : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return n < 0 || n > 2 ? 0 : n;
  }

  Widget _encryptionRow() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 8), vertical: af(context, 3)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(S.setEncryption,
                    style: TextStyle(
                        fontSize: af(context, 13),
                        height: 1.2,
                        color: cs.onSurface)),
                Text(S.setEncryptionSub,
                    style: TextStyle(
                        fontSize: af(context, 10),
                        height: 1.25,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(width: af(context, 8)),
          InkWell(
            borderRadius: BorderRadius.circular(af(context, 8)),
            onTap: _prefsLoaded ? _pickEncryption : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: af(context, 8), vertical: af(context, 5)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(S.encryptionModeName(_encryptionValue),
                      style: TextStyle(
                          fontSize: af(context, 12),
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                  Icon(Icons.expand_more_rounded,
                      size: af(context, 15), color: cs.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickEncryption() async {
    final int cur = _encryptionValue;
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.setEncryption,
            style: TextStyle(fontSize: af(context, 15))),
        contentPadding:
            EdgeInsets.symmetric(vertical: af(context, 6)),
        content: RadioGroup<int>(
          groupValue: cur,
          onChanged: (int? x) => Navigator.of(ctx).pop(x),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final int v in _isQb
                  ? const <int>[0, 1, 2]
                  : const <int>[0, 1])
                RadioListTile<int>(
                  value: v,
                  dense: true,
                  title: Text(S.encryptionModeName(v),
                      style: TextStyle(fontSize: af(context, 13))),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
        ],
      ),
    );
    if (picked == null || picked == cur) return;
    await _run(
      LogT.prefChanged(S.setEncryption),
      _okToast(S.qbSetEncryption),
      _failToast(S.qbSetEncryptionFail),
      () => _api.write(<String, dynamic>{PrefKey.encryption: picked}),
      after: () => _prefs[PrefKey.encryption] = picked,
      detail: S.encryptionModeName(picked),
    );
  }

  Widget _miscGroup() => _group(
        icon: Icons.auto_mode_rounded,
        title: L.t('自动种子管理'),
        summary: _autoMgrSummary(),
        help: S.setCategoryAutoTmmHelp,
        children: <Widget>[

          if (_supports(PrefKey.autoTmmEnabled))
            _switchRow(
              S.setEnableAutoTmm,
              _prefBool(PrefKey.autoTmmEnabled),
              (bool v) => _run(
                LogT.prefSwitch(L.t('自动种子管理'), v),
                _okToast(S.qbSetAutoTmm),
                _failToast(S.qbSetAutoTmmFail),
                () => _api.write(<String, dynamic>{PrefKey.autoTmmEnabled: v}),
                after: () => _prefs[PrefKey.autoTmmEnabled] = v,
              ),
              sub: S.setAutoTmmSub,
            ),

          if (_supports(PrefKey.preallocateAll))
            _switchRow(
              S.setPreallocate,
              _prefBool(PrefKey.preallocateAll),
              (bool v) => _run(
                LogT.prefSwitch(L.t('预分配磁盘空间'), v),
                _okToast(S.qbSetPreallocate),
                _failToast(S.qbSetPreallocateFail),
                () => _api.write(<String, dynamic>{PrefKey.preallocateAll: v}),
                after: () => _prefs[PrefKey.preallocateAll] = v,
              ),
              sub: S.setPreallocateSub,
            ),

          _switchRow(
            _isQb ? S.setUnfinishedExtQb : S.setUnfinishedExtPart,
            _prefBool('incomplete_files_ext'),
            (bool v) => _run(
              LogT.prefSwitch(L.t('未完成文件加扩展名'), v),
              _isQb
                  ? S.qbSetIncompleteQb
                  : S.setUnfinishedExtPart,
              _isQb
                  ? S.qbSetIncompleteQbFail
                  : S.execFailed,
              () => _api.write(<String, dynamic>{PrefKey.incompleteFilesExt: v}),
              after: () => _prefs['incomplete_files_ext'] = v,
            ),
            sub: _isQb ? S.setIncompleteExtSub : S.setUnfinishedExtPart,
          ),
        ],
      );

  String _autoMgrSummary() {
    int n = 0;
    if (_supports(PrefKey.autoTmmEnabled) &&
        _prefBool(PrefKey.autoTmmEnabled)) {
      n++;
    }
    if (_supports(PrefKey.preallocateAll) &&
        _prefBool(PrefKey.preallocateAll)) {
      n++;
    }
    if (_prefBool('incomplete_files_ext')) n++;
    return S.autoMgrActiveCount(n);
  }

  Widget _banGroup() => _isQb ? _qbBanGroup() : _trBlocklistGroup();

  Widget _trBlocklistGroup() => _group(
        icon: Icons.block_rounded,
        title: '黑名单 / IP 过滤',
        summary: _prefsLoaded
            ? S.entriesCount(_prefInt(PrefKey.blocklistSize) ?? 0)
            : '',
        help: L.t('Transmission 只能整份**订阅**黑名单文件（blocklist-url），\n'
            '由服务端自行下载解析；它没有逐条增删的接口。'),
        children: <Widget>[
          _switchRow(
            L.t('启用 IP 过滤'),
            _prefBool(PrefKey.ipFilterEnabled),
            (bool v) => _run(
              LogT.prefSwitch(L.t('启用 IP 过滤'), v),
              S.ipFilterOn(v),
              S.setIpFilterFail,
              () => _api.write(<String, dynamic>{PrefKey.ipFilterEnabled: v}),
              after: () => _prefs[PrefKey.ipFilterEnabled] = v,
            ),
            sub: L.t('关掉后订阅来的黑名单不再生效'),
          ),
          _pathField(L.t('订阅地址'), _blocklistUrl, prefKey: PrefKey.blocklistUrl),
          _changeButton(
            LogT.prefChanged(L.t('黑名单订阅')),
            S.blocklistSubUpdated,
            S.setBlocklistSubFail,
            () => _api.write(<String, dynamic>{
              PrefKey.blocklistUrl: _blocklistUrl.text.trim(),
            }),
            detail: LogT.detailAddr(_blocklistUrl.text.trim()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(af(context, 16), 2, af(context, 16), 6),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                _prefsLoaded
                    ? S.currentBlocked(_prefInt(PrefKey.blocklistSize) ?? 0)
                    : S.currentBlockedDash,
                style: TextStyle(fontSize: af(context, 12)),
              ),
            ),
          ),
        ],
      );

  Widget _qbBanGroup() => _group(
        icon: Icons.block_rounded,
        title: '黑名单 / IP 过滤',
        summary: _banSummary(),
        help: L.t('服务器（qBittorrent）上被封禁的来源 IP / 网段，每行一条、支持 CIDR。\n'
            '上面两个开关即时生效；名单改动点「保存黑名单」后一次性下发。'),
        children: <Widget>[
          _switchRow(
            L.t('启用 IP 过滤'),
            _banDraft.enabled,
            (bool v) => _run(
              LogT.prefSwitch(L.t('启用 IP 过滤'), v),
              S.ipFilterOn(v),
              S.setIpFilterFail,
              () => _qb!.setIpFilter(
                _banDraft.copyWith(enabled: v),
                base: _banLoaded,
              ),
              after: () => _banDraft = _banDraft.copyWith(enabled: v),
            ),
            sub: L.t('关掉后这份名单不再生效（内容保留）'),
          ),
          _switchRow(
            L.t('同时过滤 Tracker 连接'),
            _banDraft.filterTrackers,
            (bool v) => _run(
              LogT.prefSwitch(L.t('过滤 Tracker 连接'), v),
              S.trackerFilterOn(v),
              S.setIpFilterFail,
              () => _qb!.setIpFilter(
                _banDraft.copyWith(filterTrackers: v),
                base: _banLoaded,
              ),
              after: () => _banDraft = _banDraft.copyWith(filterTrackers: v),
            ),
            sub: L.t('连 tracker 也走同一份名单'),
          ),
          const Divider(height: 16, thickness: 0.6),
          _banAddRow(),
          _banSaveRow(),
          const Divider(height: 16, thickness: 0.6),
          _banListHeader(),
          ..._banListRows(),
        ],
      );

  Widget _banAddRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 8), 0, af(context, 8), 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: _bareInput(
              _banInput,
              enabled: _prefsLoaded,
              maxLength: 64,
              hint: '输入 IP 或网段，如 1.2.3.0/24',
              onSubmitted: (_) => _addBanEntry(),
            ),
          ),
          SizedBox(width: af(context, 8)),
          _pillButton(
            S.add,
            _prefsLoaded ? Theme.of(context).colorScheme.primary : null,
            (_busy || !_prefsLoaded) ? null : _addBanEntry,
            filled: true,
          ),
        ],
      ),
    );
  }

  Widget _banSaveRow() {
    final Brightness br = Theme.of(context).brightness;
    final Color dirtyColor =
        br == Brightness.dark ? const Color(0xFFE8A24A) : const Color(0xFFB26A00);
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 8), 6, af(context, 8), 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _banDirtyHint ?? '',
              style: TextStyle(fontSize: af(context, 10.5), color: dirtyColor),
            ),
          ),
          _pillButton(
            L.t('保存黑名单'),
            _banDirtyHint == null ? null : Theme.of(context).colorScheme.primary,
            (_busy || !_prefsLoaded || _banDirtyHint == null)
                ? null
                : _saveBanList,
            filled: true,
          ),
        ],
      ),
    );
  }

  String? get _banDirtyHint {
    final QbIpFilter? base = _banLoaded;
    if (base == null || !_banTouched) return null;
    if (_banDraft.bannedIps == base.bannedIps) return null;
    final int d = _banDraft.count - base.count;
    return d == 0
        ? S.dirtyUnsaved
        : S.dirtyCount(d);
  }

  Widget _banListHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 16), 0, af(context, 8), 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _prefsLoaded ? '已封禁 ${_banDraft.count} 条' : '已封禁 —',
              style: TextStyle(
                  fontSize: af(context, 12.5), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: (_busy || !_prefsLoaded) ? null : _bulkEditBanList,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(L.t('批量编辑'), style: TextStyle(fontSize: af(context, 11.5))),
          ),
        ],
      ),
    );
  }

  List<Widget> _banListRows() {
    if (!_prefsLoaded) {
      return <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: af(context, 16), vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: Text(L.t('未读取到服务器设置'), style: TextStyle(fontSize: af(context, 12))),
          ),
        ),
      ];
    }
    final List<String> list = _banDraft.entries;
    if (list.isEmpty) {
      return <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: af(context, 16), vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: Text(L.t('名单为空'), style: TextStyle(fontSize: af(context, 12))),
          ),
        ),
      ];
    }
    final int shown =
        _banShowAll ? list.length : list.length.clamp(0, _kBanPreview);
    final List<Widget> rows = <Widget>[
      for (int i = 0; i < shown; i++) _banRow(i, list[i]),
    ];
    if (shown < list.length) {
      rows.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: af(context, 8), bottom: 4),
            child: TextButton(
              onPressed: () => setState(() => _banShowAll = true),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(L.pick('显示全部（还有 ${list.length - shown} 条）', 'Show all (${list.length - shown} more)'),
                  style: TextStyle(fontSize: af(context, 11.5))),
            ),
          ),
        ),
      );
    }
    return rows;
  }

  String _geoLine(String entry) {
    if (_geo.containsKey(entry)) return _decorate(entry, _geo[entry]);
    final String ip = _ipPart(entry);
    if (!Formatter.ipNeedsLookup(ip)) {
      _geo[entry] = Formatter.getIpInfo(ip);
      return _decorate(entry, _geo[entry]);
    }
    _geo[entry] = null;
    _geoLoading.add(entry);
    unawaited(_fetchGeo(entry));
    return S.geoSearching;
  }

  Future<void> _fetchGeo(String entry) async {
    final String? text = await IpGeo.instance.lookup(_ipPart(entry));
    if (!mounted) return;
    setState(() {
      _geo[entry] = (text == null || text.isEmpty) ? S.geoUnknown : text;
      _geoLoading.remove(entry);
    });
  }

  String _decorate(String entry, String? geo) {
    if (geo == null) return S.geoSearching;
    final int? n = _cidrCount(entry);
    return n == null ? geo : S.geoRange(geo, n);
  }

  static String _ipPart(String entry) {
    final int i = entry.indexOf('/');
    return (i < 0 ? entry : entry.substring(0, i)).trim();
  }

  static int? _cidrCount(String entry) {
    final int i = entry.indexOf('/');
    if (i < 0) return null;
    final int? bits = int.tryParse(entry.substring(i + 1).trim());
    if (bits == null || bits < 8 || bits > 30) return null;
    return 1 << (32 - bits);
  }

  Widget _banRow(int index, String ip) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 8), 2, 4, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        ip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: af(context, 14)),
                      ),
                    ),
                    if (ip.contains('/'))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusTiny),
                          ),
                          child: Text(L.t('网段'),
                              style: TextStyle(
                                  fontSize: af(context, 9.5), color: cs.onSurfaceVariant)),
                        ),
                      ),
                  ],
                ),

                Row(
                  children: <Widget>[
                    if (_geoLoading.contains(ip)) ...<Widget>[
                      SizedBox(
                        width: af(context, 9),
                        height: 9,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.4, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        _geoLine(ip),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: af(context, 10.5), color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: af(context, 15)),
            visualDensity: VisualDensity.compact,
            tooltip: L.t('编辑'),
            onPressed: _busy ? null : () => _editBanEntry(index, ip),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: af(context, 15)),
            visualDensity: VisualDensity.compact,
            tooltip: L.t('删除'),
            onPressed: _busy ? null : () => _removeBanEntry(index, ip),
          ),
        ],
      ),
    );
  }

  void _addBanEntry() {
    final String v = _banInput.text.trim();
    if (v.isEmpty) return;
    if (!QbIpFilter.isValidEntry(v)) {
      UiDialogs.showToast(S.badIpFormat(v), isError: true);
      AppLog.instance.op(LogT.prefRejected(L.t('黑名单'), v),
          level: 'ERROR', scope: _server?.logScope);
      return;
    }
    final List<String> list = _banDraft.entries;
    if (list.contains(v)) {
      UiDialogs.showToast(S.dupIp(v));
      return;
    }
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(
        bannedIps: QbIpFilter.joinEntries(QbIpFilter.addEntry(list, v)),
      );
      _banInput.clear();
    });
    AppLog.instance.act('服务器设置', LogT.blacklistAdded(v, _banDraft.count),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));
  }

  Future<void> _editBanEntry(int index, String old) async {
    final String? v = await _promptText(
      title: L.t('编辑黑名单条目'),
      label: L.t('IP 或网段'),
      help: L.pick('支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\n'
          '确定后只改本地草稿，点「保存黑名单」才下发。当前值：$old',
          'Supports a single IP (1.2.3.4) or CIDR range (1.2.3.0/24).\n'
          'OK updates the local draft only; it goes live when you tap "Save blocklist". Current: $old'),
    );
    if (v == null) {
      AppLog.instance.act('服务器设置', L.t('黑名单[编辑]·取消'), target: old);
      return;
    }
    final String nv = v.trim();
    if (!QbIpFilter.isValidEntry(nv)) {
      UiDialogs.showToast(S.badIpFormat(nv), isError: true);
      AppLog.instance.op(LogT.prefRejected(L.t('黑名单'), nv),
          level: 'ERROR', scope: _server?.logScope);
      return;
    }
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(
        bannedIps: QbIpFilter.joinEntries(
          QbIpFilter.replaceEntry(_banDraft.entries, index, nv),
        ),
      );
    });
    AppLog.instance.act('服务器设置', LogT.blacklistEdited(old, nv),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));
  }

  void _removeBanEntry(int index, String ip) {
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(
        bannedIps: QbIpFilter.joinEntries(
          QbIpFilter.removeEntry(_banDraft.entries, index),
        ),
      );
    });
    AppLog.instance.act('服务器设置', LogT.blacklistDeleted(ip),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));
  }

  Future<void> _bulkEditBanList() async {
    final int before = _banDraft.count;
    final String? text = await _promptMultiline(
      title: L.t('批量编辑黑名单'),
      initial: _banDraft.bannedIps,
      help: L.pick('每行一条，支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\n'
          '确定后整份替换本地草稿，再点「保存黑名单」下发。',
          'One entry per line; a single IP (1.2.3.4) or CIDR range (1.2.3.0/24).\n'
          'OK replaces the whole local draft; tap "Save blocklist" to apply.'),
    );
    if (text == null) {
      AppLog.instance.act('服务器设置', L.t('黑名单[批量编辑]·取消'));
      return;
    }
    final List<String> lines = QbIpFilter.splitEntries(text);
    final List<String> bad =
        lines.where((String e) => !QbIpFilter.isValidEntry(e)).toList();
    if (bad.isNotEmpty) {
      UiDialogs.showToast(S.banRowsBad(bad.length, bad.first),
          isError: true);
      AppLog.instance.op(
          LogT.prefRejected(L.t('黑名单批量编辑'),
              '${bad.length} 行（例 ${bad.first}）'),
          level: 'ERROR',
          scope: _server?.logScope);
      return;
    }
    if (lines.length > QbIpFilter.maxEntries) {
      UiDialogs.showToast(S.banMaxRows(QbIpFilter.maxEntries), isError: true);
      return;
    }
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(bannedIps: QbIpFilter.joinEntries(lines));
      _banShowAll = false;
    });
    AppLog.instance.act('服务器设置', L.t('黑名单[批量编辑]'),
        target: _server?.name, detail: S.rowsTransition(before, lines.length));
  }

  Future<void> _saveBanList() async {
    final QbIpFilter? base = _banLoaded;
    final QbIpFilter next = _banDraft;
    await _run(
      LogT.prefChanged(L.t('黑名单')),
      S.blacklistSaved(next.count),
      L.t('保存黑名单失败'),
      () => _qb!.setIpFilter(next, base: base),
      after: () => _banTouched = false,
      detail: base == null ? S.banSaveDetail(next.count) : next.diffSummary(base),
    );
  }

  Widget _prefsErrorNotice() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(af(context, 16), af(context, 10), af(context, 16), 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: AppTheme.iconSize, color: cs.error),
          SizedBox(width: af(context, 8)),
          Expanded(
            child: Text(
              S.loadFailHint(_prefsError ?? ''),
              style: TextStyle(fontSize: af(context, 12), color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptMultiline({
    required String title,
    required String initial,
    String? help,
  }) {
    final TextEditingController c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: af(context, 15))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (help != null)
              Padding(
                padding: EdgeInsets.only(bottom: af(context, 8)),
                child: Text(help, style: TextStyle(fontSize: af(context, 10))),
              ),
            TextField(
              controller: c,
              maxLines: 8,
              minLines: 5,
              style: TextStyle(fontSize: af(context, 13)),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(S.execute),
          ),
        ],
      ),

    ).whenComplete(c.dispose);
  }

  final Set<String> _openGroups = <String>{};

  Widget _group({
    required IconData icon,
    required String title,
    String? summary,
    required List<Widget> children,
    String? help,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool open = _openGroups.contains(title);
    return Container(
      margin: EdgeInsets.fromLTRB(
          af(context, 12), 0, af(context, 12), af(context, 8)),
      child: Material(
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(af(context, 12)),
          side: BorderSide(
            color: open
                ? cs.primary.withValues(alpha: 0.28)
                : cs.outlineVariant.withValues(alpha: 0.30),
            width: 0.8,
          ),
        ),
        child: Theme(

        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: af(context, 12)),
          initiallyExpanded: false,
          onExpansionChanged: (bool v) => setState(() {
            if (v) {
              _openGroups.add(title);
            } else {
              _openGroups.remove(title);
            }
          }),
          title: Row(
            children: <Widget>[
              Icon(icon, size: af(context, 17), color: cs.primary),
              SizedBox(width: af(context, 7)),
              Text(
                title,
                style: TextStyle(
                  fontSize: af(context, 13.5),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              if (summary != null && summary.isNotEmpty) ...<Widget>[
                SizedBox(width: af(context, 7)),
                Flexible(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: af(context, 10.5),
                        color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
          childrenPadding: EdgeInsets.only(
              left: af(context, 4),
              right: af(context, 4),
              bottom: af(context, 8)),
          children: <Widget>[
            if (help != null)
              Padding(
                padding:
                    EdgeInsets.fromLTRB(af(context, 8), 0, af(context, 8), 6),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(help,
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: af(context, 10))),
                ),
              ),
            ...children,
          ],
        ),
      ),
      ),
    );
  }

  Widget _switchRow(
    String label,
    bool value,
    ValueChanged<bool>? onChanged, {
    String? sub,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 8), vertical: af(context, 3)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label,
                    style: TextStyle(
                        fontSize: af(context, 13),
                        height: 1.2,
                        color: cs.onSurface)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(
                          fontSize: af(context, 10),
                          height: 1.25,
                          color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(width: af(context, 8)),
          Transform.scale(
            scale: 0.78,
            child: CupertinoSwitch(
              value: value,
              onChanged: _prefsLoaded ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridRow(List<Widget> cells) {
    if (cells.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding:
          EdgeInsets.fromLTRB(af(context, 4), af(context, 4), af(context, 4), 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < cells.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: af(context, 6)),
            cells[i],
          ],
        ],
      ),
    );
  }

  Widget _numCell(
    String label,
    TextEditingController c, {
    String? prefKey,
    String? unit,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 9), vertical: af(context, 6)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(af(context, 8)),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: af(context, 9.5), color: cs.onSurfaceVariant)),
          SizedBox(height: af(context, 2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: c,
                  maxLength: AppTheme.maxLenGeneral,
                  buildCounter: AppTheme.noCounter,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      fontSize: af(context, 13),
                      fontWeight: FontWeight.w700,
                      height: 1.1),
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: prefKey != null && !_prefsLoaded ? '--' : null,
                    hintStyle: TextStyle(
                        fontSize: af(context, 13),
                        fontWeight: FontWeight.w700),
                  ),
                  onChanged: prefKey == null
                      ? null
                      : (String _) => setState(() => _touched.add(prefKey)),
                ),
              ),
              if (unit != null) ...<Widget>[
                SizedBox(width: af(context, 3)),
                Text(unit,
                    style: TextStyle(
                        fontSize: af(context, 8),
                        height: 1.7,
                        color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 做种限制行：启用开关 + 标签 + 右侧定宽数值输入。行式布局替代原三列网格
  /// （Mate 80 Pro 445dp 下三列网格标签必截断），尺寸全部走 af() 自适应，
  /// 宽屏与窄屏同构；标签最多两行，保证卓易通字体缩放下不丢失内容
  Widget _seedingRow(
    String label,
    TextEditingController c, {
    String? prefKey,
    String? unit,
    bool enabled = false,
    ValueChanged<bool>? onEnabledChanged,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(vertical: af(context, 3)),
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 9), vertical: af(context, 2)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(af(context, 8)),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        children: <Widget>[
          if (onEnabledChanged != null) ...<Widget>[
            Transform.scale(
              scale: 0.78,
              child: CupertinoSwitch(
                value: enabled,
                onChanged: _prefsLoaded ? onEnabledChanged : null,
              ),
            ),
            SizedBox(width: af(context, 6)),
          ],
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: af(context, 12), color: cs.onSurface)),
          ),
          SizedBox(width: af(context, 8)),
          SizedBox(
            width: af(context, 92),
            child: TextField(
              controller: c,
              maxLength: AppTheme.maxLenGeneral,
              buildCounter: AppTheme.noCounter,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: af(context, 13),
                  fontWeight: FontWeight.w700,
                  height: 1.1),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: prefKey != null && !_prefsLoaded ? '--' : null,
                hintStyle: TextStyle(
                    fontSize: af(context, 13), fontWeight: FontWeight.w700),
              ),
              onChanged: prefKey == null
                  ? null
                  : (String _) => setState(() => _touched.add(prefKey)),
            ),
          ),
          if (unit != null) ...<Widget>[
            SizedBox(width: af(context, 3)),
            Text(unit,
                style: TextStyle(
                    fontSize: af(context, 9), color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _bareInput(
    TextEditingController c, {
    bool enabled = true,
    int? maxLength,
    String? hint,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: af(context, 34),
      padding: EdgeInsets.symmetric(horizontal: af(context, 9)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(af(context, 8)),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45), width: 0.8),
      ),
      child: TextField(
        controller: c,
        enabled: enabled,
        maxLength: maxLength,
        buildCounter: AppTheme.noCounter,
        style: TextStyle(fontSize: af(context, 12.5), color: cs.onSurface),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: af(context, 11.5),
              color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
        onSubmitted: onSubmitted,
        onChanged: onChanged,
      ),
    );
  }

  Widget _pathField(
    String label,
    TextEditingController c, {
    String? prefKey,
    String? hint,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 8), vertical: af(context, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label,
              style: TextStyle(
                  fontSize: af(context, 13),
                  color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: af(context, 4)),
          _bareInput(
            c,
            maxLength: AppTheme.maxLenGeneral,
            hint: hint ?? (prefKey != null && !_prefsLoaded ? '--' : null),
            onChanged: prefKey == null
                ? null
                : (_) => setState(() => _touched.add(prefKey)),
          ),
        ],
      ),
    );
  }

  Widget _pathDropdownField(String label, TextEditingController c) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: af(context, 8), vertical: af(context, 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label,
              style: TextStyle(
                  fontSize: af(context, 13),
                  color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: af(context, 4)),
          PathDropdownField(
            controller: c,
            candidates: _pathCandidates(),
            label: label,
          ),
        ],
      ),
    );
  }

  List<PathCandidate> _pathCandidates() {
    final TorrentController tc = Get.find<TorrentController>();
    return PathCandidates.build(
      defaultPath: _savePath.text,
      tempPath: _tempPath.text,
      categoryPaths: tc.categoryPaths,
      seedPaths: tc.seedPathCounts,
    );
  }

  String _onOffLabel(bool v) => v ? S.stateEnabled : S.stateDisabled;

  String _banSummary() {
    if (!_prefsLoaded) return '';
    final QbIpFilter? base = _banLoaded;
    String extra = '';
    if (_banTouched &&
        base != null &&
        _banDraft.bannedIps != base.bannedIps) {
      final int d = _banDraft.count - base.count;
      if (d != 0) extra = ' · ${d > 0 ? '+' : ''}$d';
    }
    return '${_banDraft.count}${L.t(' 条')}$extra';
  }

  Widget _pillButton(
    String label,
    Color? color,
    VoidCallback? onPressed, {
    bool filled = false,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color tint = color ?? cs.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: af(context, 4)),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled ? (color ?? Colors.transparent) : Colors.transparent,
          foregroundColor: filled ? cs.onPrimary : tint,
          side: filled
              ? null
              : BorderSide(color: tint.withValues(alpha: 0.55)),
          shape: const StadiumBorder(),
          padding: EdgeInsets.symmetric(horizontal: af(context, 12)),
          minimumSize: Size(0, af(context, 28)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_rounded, size: af(context, 12)),
            SizedBox(width: af(context, 3)),
            Text(label,
                style: TextStyle(
                    fontSize: af(context, 11.5),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _changeButton(
    String label,
    String okMsg,
    String failMsg,
    Future<void> Function() act, {
    String? detail,
    bool refreshLimit = false,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: af(context, 4)),
        child: _pillButton(
          S.change,
          Theme.of(context).colorScheme.primary,
          _busy
              ? null
              : () => _run(label, okMsg, failMsg, act,
                  detail: detail, refreshLimit: refreshLimit),
        ),
      ),
    );
  }

  Widget _actionRow({required VoidCallback onAdd, required VoidCallback onDelete}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: af(context, 4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _busy ? null : onDelete,
              child: Text(S.delete, style: TextStyle(fontSize: af(context, 12))),
            ),
            SizedBox(width: af(context, 6)),
            _pillButton(
              S.add,
              Theme.of(context).colorScheme.primary,
              _busy ? null : onAdd,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String? help,
  }) {
    final TextEditingController c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: af(context, 15))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (help != null)
              Padding(
                padding: EdgeInsets.only(bottom: af(context, 8)),
                child: Text(help, style: TextStyle(fontSize: af(context, 10))),
              ),
            TextField(
              controller: c,
              maxLength: AppTheme.maxLenGeneral,
              buildCounter: AppTheme.noCounter,
              autofocus: true,
              style: TextStyle(fontSize: af(context, 13)),
              decoration: InputDecoration(labelText: label, isDense: true),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(S.execute),
          ),
        ],
      ),

    ).whenComplete(c.dispose);
  }
}
