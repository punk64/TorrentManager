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
import '../utils/ip_geo.dart';
import '../utils/net_error.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';




















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
    return (e == null || e.isEmpty) ? '未能在服务器上建立会话' : e;
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
        AppLog.instance.net('服务器设置：未能建立会话 —— $reason',
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
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        _prefsLoaded = false;
        _prefsError = NetError.describe(e);
      });
      AppLog.instance.net('读取服务器偏好失败：${NetError.describe(e)}',
        scope: _server?.logScope);
    }
  }

  
  
  
  
  
  
  
  
  bool get _isSupported => _server != null;

  
  
  
  
  bool get _isQb => _api.isQb;

  
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
  }) async {
    
    AppLog.instance.act('服务器设置', label,
        target: _server?.name, detail: detail);
    setState(() => _busy = true);
    try {
      await act();
      Formatter.showToast(okMsg);
      after?.call();
      await _loadCategoriesAndTags();
      
      
      await _loadPreferences();
    } catch (e) {
      
      AppLog.instance.op('$label 失败：${Formatter.safeErr(e)}',
          level: 'ERROR', scope: _server?.logScope);
      Formatter.showToast('$failMsg ${Formatter.safeErr(e)}', isError: true);
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
        title: Text(name.isEmpty ? '服务器设置' : '$name · 服务器设置'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh, size: AppTheme.iconSize),
            tooltip: S.fieldUpdating,
            
            
            onPressed: () async {
              AppLog.instance.act('服务器设置', 'AppBar[刷新]',
                  target: _server?.name, detail: '重开会话 + 重拉偏好 + 分类标签');
              
              
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
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            
            
            
            
            
            
            
            
            if (_server == null)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text(S.noServer,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            if (_server != null && _prefsError != null) _prefsErrorNotice(),
            if (_server != null) ...<Widget>[
              _globalLimitGroup(),
              _altLimitGroup(),
              
              
              
              if (_isQb) _categoryGroup(),
              if (_isQb) _tagGroup(),
              _savePathGroup(),
              _tempPathGroup(),
              _queueGroup(),
              _seedingGroup(),
              _connectionGroup(),
              _miscGroup(),
              _banGroup(),
            ],
          ],
        ),
      ),
    );
  }

  

  Widget _globalLimitGroup() => _group(
        title: '设置全局限速',
        help: '${S.setNoLimitZero}\n${S.setSwitchToEnable}',
        children: <Widget>[
          _kbRow('上传限速', _upLimit, prefKey: PrefKey.upLimit),
          _kbRow('下载限速', _dlLimit, prefKey: PrefKey.dlLimit),
          _changeButton(
            '全局限速[更改]',
            S.qbSetServerLimit,
            S.qbSetServerLimitFail,
            
            () => _api.write(<String, dynamic>{
              PrefKey.upLimit: _kb(_upLimit),
              PrefKey.dlLimit: _kb(_dlLimit),
            }),
            detail:
                '上行 ${_kbText(_upLimit)} KB/s · 下行 ${_kbText(_dlLimit)} KB/s',
          ),
        ],
      );

  

  Widget _altLimitGroup() => _group(
        title: '设置备用限速',
        help: S.setAltLimitHelp,
        children: <Widget>[
          
          
          
          
          
          _switchRow(
            S.setEnableAltLimit,
            _ssBool(PrefKey.altSpeedEnabled),
            (bool v) => _run(
              '开关[启用备用限速]${v ? ' → 开' : ' → 关'}',
              S.qbSetAltLimit,
              S.qbSetAltLimitFail,
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
            ),
          ),
          _kbRow(
            '上传限速',
            _altUpLimit,
            prefKey: 'alt_up_limit',
          ),
          _kbRow(
            '下载限速',
            _altDlLimit,
            prefKey: 'alt_dl_limit',
          ),
          _changeButton(
            '备用限速[更改]',
            S.qbSetAltLimit,
            S.qbSetAltLimitFail,
            () => _api.write(<String, dynamic>{
              PrefKey.altUpLimit: _kb(_altUpLimit),
              PrefKey.altDlLimit: _kb(_altDlLimit),
            }),
            detail:
                '上行 ${_kbText(_altUpLimit)} KB/s · 下行 ${_kbText(_altDlLimit)} KB/s',
          ),
        ],
      );

  

  Widget _categoryGroup() => _group(
        title: '管理分类',
        help: S.setCategoryEditHelp,
        children: <Widget>[
          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('未分类', style: TextStyle(fontSize: 12)),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String c in _categories)
                FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
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
      label: '类别名称',
      help: S.setPickFromBelow,
    );
    if (name == null || name.trim().isEmpty) {
      if (name != null) Formatter.showToast(S.catNameEmpty, isError: true);
      return;
    }
    await _run(
      '分类[新增]：${name.trim()}',
      '${S.catCreatedPlain}: $name',
      S.execFailed,
      () => _qb!.createCategory(name.trim()),
      detail: '改前 ${_categories.length} 个（点「更改」才提交）',
    );
  }

  Future<void> _removeSelectedCategories() async {
    if (_selectedCategories.isEmpty) {
      Formatter.showToast(S.pleaseSelectCategory, isError: true);
      return;
    }
    final String joined = _selectedCategories.join('\n');
    await _run(
      '分类[删除]：${_selectedCategories.join('、')}',
      '${S.catRemovedPlain}: $joined',
      S.execFailed,
      () => _qb!.removeCategories(joined),
      after: () => _selectedCategories.clear(),
      detail: '改前 ${_categories.length} 个',
    );
  }

  

  Widget _tagGroup() => _group(
        title: '管理标签',
        help: S.setTagDeleteHelp,
        children: <Widget>[
          if (_tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('无标签', style: TextStyle(fontSize: 12)),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final String t in _tags)
                FilterChip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
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
        await _promptText(title: S.add, label: '标签名称', help: S.setAddNewLineHelp);
    if (name == null || name.trim().isEmpty) return;
    await _run(
      '标签[新增]：${name.trim()}',
      '${S.tagCreatedPlain}: ${name.trim()}',
      S.execFailed,
      () => _qb!.createTags(name.trim()),
      detail: '改前 ${_tags.length} 个',
    );
  }

  Future<void> _removeSelectedTags() async {
    if (_selectedTags.isEmpty) {
      Formatter.showToast(S.pleaseSelectTag, isError: true);
      return;
    }
    final String joined = _selectedTags.join('\n');
    await _run(
      '标签[删除]：${_selectedTags.join('、')}',
      '${S.tagRemovedPlain}: $joined',
      S.execFailed,
      () => _qb!.deleteTags(joined),
      after: () => _selectedTags.clear(),
      detail: '改前 ${_tags.length} 个',
    );
  }

  

  Widget _savePathGroup() => _group(
        title: '默认保存路径',
        help: S.setPickFromBelowNoAutoTmm,
        children: <Widget>[
          _textRow('保存路径', _savePath, prefKey: 'save_path'),
          _changeButton(
            '保存路径[更改]',
            S.qbSetSavePath,
            S.qbSetSavePathFail,
            () => _api.write(<String, dynamic>{
              PrefKey.savePath: _savePath.text.trim(),
            }),
            detail: '路径 ${_savePath.text.trim()}',
          ),
        ],
      );

  

  Widget _tempPathGroup() => _group(
        title: '临时保存路径',
        help: S.setTempPathHelp,
        children: <Widget>[
          
          
          
          _switchRow(
            S.setEnableTempPath,
            _prefBool('temp_path_enabled'),
            (bool v) => _run(
              '开关[启用临时保存路径]${v ? ' → 开' : ' → 关'}',
              S.qbSetTempPath,
              S.qbSetTempPathFail,
              () => _api.write(<String, dynamic>{PrefKey.tempPathEnabled: v}),
              after: () => _prefs['temp_path_enabled'] = v,
            ),
          ),
          _textRow('临时路径', _tempPath, prefKey: 'temp_path'),
          _changeButton(
            '临时路径[更改]',
            S.qbSetTempPath,
            S.qbSetTempPathFail,
            () => _api.write(<String, dynamic>{
              PrefKey.tempPath: _tempPath.text.trim(),
            }),
            detail: '路径 ${_tempPath.text.trim()}',
          ),
        ],
      );

  

  Widget _queueGroup() => _group(
        title: '设置队列限制',
        help: S.setQueueSwitchHelp,
        children: <Widget>[
          _switchRow(
            S.setEnableQueueLimit,
            
            
            
            _prefBool('queueing_enabled'),
            (bool v) => _run(
              '开关[启用队列限制]${v ? ' → 开' : ' → 关'}',
              S.qbSetQueueing,
              S.qbSetQueueingFail,
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
          
          
          
          if (_supports(PrefKey.maxActiveUploads))
            _textRow('最大活动上传数', _maxActiveUp,
                numeric: true, prefKey: PrefKey.maxActiveUploads),
          if (_supports(PrefKey.maxActiveDownloads))
            _textRow('最大活动下载数', _maxActiveDl,
                numeric: true, prefKey: PrefKey.maxActiveDownloads),
          if (_supports(PrefKey.maxActiveTorrents))
            _textRow('最大活动种子数', _maxActiveTorrents,
                numeric: true, prefKey: PrefKey.maxActiveTorrents),
          _changeButton(
            '队列限制[更改]',
            S.qbSetQueueing,
            S.qbSetQueueingFail,
            () => _api.write(<String, dynamic>{
              PrefKey.maxActiveUploads: int.tryParse(_maxActiveUp.text.trim()),
              PrefKey.maxActiveDownloads:
                  int.tryParse(_maxActiveDl.text.trim()),
              PrefKey.maxActiveTorrents:
                  int.tryParse(_maxActiveTorrents.text.trim()),
            }),
            detail: '上传 ${_kbText(_maxActiveUp)} / 下载 '
                '${_kbText(_maxActiveDl)} / 种子 ${_kbText(_maxActiveTorrents)}',
          ),
        ],
      );

  

  Widget _seedingGroup() => _group(
        title: '设置做种限制',
        help: S.setRatioHelp,
        children: <Widget>[
          _textRow('最大分享比率', _maxRatio,
              help: S.setNoLimitMinusOneShort, prefKey: PrefKey.maxRatio),
          
          
          if (_supports(PrefKey.maxSeedingTime))
            _textRow('最长做种时间', _maxSeedingTime,
                numeric: true, prefKey: PrefKey.maxSeedingTime),
          _textRow('非活动状态下\n最长做种时间', _maxInactiveSeedingTime,
              numeric: true, prefKey: PrefKey.maxInactiveSeedingTime),
          _changeButton(
            '做种限制[更改]',
            S.qbSetRatio,
            S.qbSetRatioFail,
            () => _api.write(<String, dynamic>{
              PrefKey.maxRatio: double.tryParse(_maxRatio.text.trim()) ?? -1,
              
              
              PrefKey.maxRatioEnabled: true,
              PrefKey.maxSeedingTime:
                  int.tryParse(_maxSeedingTime.text.trim()) ?? -1,
              PrefKey.maxInactiveSeedingTime:
                  int.tryParse(_maxInactiveSeedingTime.text.trim()) ?? -1,
            }),
            detail: '比率 ${_kbText(_maxRatio)} · 做种 '
                '${_kbText(_maxSeedingTime)} · 非活动 '
                '${_kbText(_maxInactiveSeedingTime)}',
          ),
        ],
      );

  

  Widget _connectionGroup() => _group(
        title: '设置连接限制',
        help: S.setQueueSwitchHelp,
        children: <Widget>[
          _textRow('全局最大连接数', _maxConnec,
              numeric: true, prefKey: PrefKey.maxConnec),
          _textRow('单种最大连接数', _maxConnecPerTorrent,
              numeric: true, prefKey: PrefKey.maxConnecPerTorrent),
          
          if (_supports(PrefKey.maxUploads))
            _textRow('全局上传连接数', _maxUpConnec,
                numeric: true, prefKey: PrefKey.maxUploads),
          _textRow('单种上传连接数', _maxUpConnecPerTorrent,
              numeric: true, prefKey: PrefKey.maxUploadsPerTorrent),
          _changeButton(
            '连接限制[更改]',
            S.qbSetMaxConnec,
            S.qbSetMaxConnecFail,
            () => _api.write(<String, dynamic>{
              PrefKey.maxConnec: int.tryParse(_maxConnec.text.trim()),
              PrefKey.maxConnecPerTorrent:
                  int.tryParse(_maxConnecPerTorrent.text.trim()),
              PrefKey.maxUploads: int.tryParse(_maxUpConnec.text.trim()),
              PrefKey.maxUploadsPerTorrent:
                  int.tryParse(_maxUpConnecPerTorrent.text.trim()),
            }),
            detail: '全局 ${_kbText(_maxConnec)} / 单种 '
                '${_kbText(_maxConnecPerTorrent)} / 连接 '
                '${_kbText(_maxUpConnec)} / 单种连接 '
                '${_kbText(_maxUpConnecPerTorrent)}',
          ),
        ],
      );

  

  Widget _miscGroup() => _group(
        title: '自动种子管理',
        help: S.setCategoryAutoTmmHelp,
        children: <Widget>[
          
          if (_supports(PrefKey.autoTmmEnabled))
            _switchRow(
              S.setEnableAutoTmm,
              _prefBool(PrefKey.autoTmmEnabled),
              (bool v) => _run(
                '开关[自动种子管理]${v ? ' → 开' : ' → 关'}',
                S.qbSetAutoTmm,
                S.qbSetAutoTmmFail,
                () => _api.write(<String, dynamic>{PrefKey.autoTmmEnabled: v}),
                after: () => _prefs[PrefKey.autoTmmEnabled] = v,
              ),
            ),
          
          if (_supports(PrefKey.preallocateAll))
            _switchRow(
              S.setPreallocate,
              _prefBool(PrefKey.preallocateAll),
              (bool v) => _run(
                '开关[预分配磁盘空间]${v ? ' → 开' : ' → 关'}',
                S.qbSetPreallocate,
                S.qbSetPreallocateFail,
                () => _api.write(<String, dynamic>{PrefKey.preallocateAll: v}),
                after: () => _prefs[PrefKey.preallocateAll] = v,
              ),
            ),
          
          
          
          
          
          
          
          _switchRow(
            S.setUnfinishedExtQb,
            _prefBool('incomplete_files_ext'),
            (bool v) => _run(
              '开关[未完成文件加扩展名]${v ? ' → 开' : ' → 关'}',
              S.qbSetIncompleteQb,
              S.qbSetIncompleteQbFail,
              () => _api.write(<String, dynamic>{PrefKey.incompleteFilesExt: v}),
              after: () => _prefs['incomplete_files_ext'] = v,
            ),
          ),
        ],
      );

  

  
  
  
  
  
  
  
  
  
  
  Widget _banGroup() => _isQb ? _qbBanGroup() : _trBlocklistGroup();

  
  
  
  
  
  Widget _trBlocklistGroup() => _group(
        title: '黑名单 / IP 过滤',
        help: 'Transmission 只能整份**订阅**黑名单文件（blocklist-url），\n'
            '由服务端自行下载解析；它没有逐条增删的接口。',
        children: <Widget>[
          _switchRow(
            '启用 IP 过滤',
            _prefBool(PrefKey.ipFilterEnabled),
            (bool v) => _run(
              '开关[启用 IP 过滤]${v ? ' → 开' : ' → 关'}',
              v ? '已启用 IP 过滤' : '已关闭 IP 过滤',
              '设置 IP 过滤失败',
              () => _api.write(<String, dynamic>{PrefKey.ipFilterEnabled: v}),
              after: () => _prefs[PrefKey.ipFilterEnabled] = v,
            ),
            sub: '关掉后订阅来的黑名单不再生效',
          ),
          _textRow('订阅地址', _blocklistUrl, prefKey: PrefKey.blocklistUrl),
          _changeButton(
            '黑名单订阅[更改]',
            '黑名单订阅已更新',
            '设置黑名单订阅失败',
            () => _api.write(<String, dynamic>{
              PrefKey.blocklistUrl: _blocklistUrl.text.trim(),
            }),
            detail: '地址 ${_blocklistUrl.text.trim()}',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(
              _prefsLoaded
                  ? '当前屏蔽 ${_prefInt(PrefKey.blocklistSize) ?? 0} 条'
                  : '当前屏蔽 —',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      );

  
  Widget _qbBanGroup() => _group(
        title: '黑名单 / IP 过滤',
        help: '服务器（qBittorrent）上被封禁的来源 IP / 网段，每行一条、支持 CIDR。\n'
            '上面两个开关即时生效；名单改动点「保存黑名单」后一次性下发。',
        children: <Widget>[
          _switchRow(
            '启用 IP 过滤',
            _banDraft.enabled,
            (bool v) => _run(
              '开关[启用 IP 过滤]${v ? ' → 开' : ' → 关'}',
              v ? '已启用 IP 过滤' : '已关闭 IP 过滤',
              '设置 IP 过滤失败',
              () => _qb!.setIpFilter(
                _banDraft.copyWith(enabled: v),
                base: _banLoaded,
              ),
              after: () => _banDraft = _banDraft.copyWith(enabled: v),
            ),
            sub: '关掉后这份名单不再生效（内容保留）',
          ),
          _switchRow(
            '同时过滤 Tracker 连接',
            _banDraft.filterTrackers,
            (bool v) => _run(
              '开关[过滤 Tracker 连接]${v ? ' → 开' : ' → 关'}',
              v ? '已同时过滤 Tracker 连接' : '已只过滤普通连接',
              '设置 IP 过滤失败',
              () => _qb!.setIpFilter(
                _banDraft.copyWith(filterTrackers: v),
                base: _banLoaded,
              ),
              after: () => _banDraft = _banDraft.copyWith(filterTrackers: v),
            ),
            sub: '连 tracker 也走同一份名单',
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _banInput,
                enabled: _prefsLoaded,
                maxLength: 64,
                buildCounter: AppTheme.noCounter,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '输入 IP 或网段，如 1.2.3.0/24',
                  hintStyle: TextStyle(fontSize: 11.5),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                ),
                onSubmitted: (_) => _addBanEntry(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (_busy || !_prefsLoaded) ? null : _addBanEntry,
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('添加', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  
  
  
  Widget _banSaveRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _banDirtyHint ?? '',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFB26A00)),
            ),
          ),
          ElevatedButton(
            onPressed: (_busy || !_prefsLoaded || _banDirtyHint == null)
                ? null
                : _saveBanList,
            child: const Text('保存黑名单', style: TextStyle(fontSize: 12)),
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
        ? '名单有改动，未保存'
        : '名单有改动（${d > 0 ? '+' : ''}$d 条），未保存';
  }

  Widget _banListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _prefsLoaded ? '已封禁 ${_banDraft.count} 条' : '已封禁 —',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: (_busy || !_prefsLoaded) ? null : _bulkEditBanList,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: const Text('批量编辑', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  
  
  
  
  List<Widget> _banListRows() {
    if (!_prefsLoaded) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text('未读取到服务器设置', style: TextStyle(fontSize: 12)),
        ),
      ];
    }
    final List<String> list = _banDraft.entries;
    if (list.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text('名单为空', style: TextStyle(fontSize: 12)),
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
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: TextButton(
              onPressed: () => setState(() => _banShowAll = true),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text('显示全部（还有 ${list.length - shown} 条）',
                  style: const TextStyle(fontSize: 11.5)),
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
    return '查询归属地…';
  }

  
  
  
  
  
  Future<void> _fetchGeo(String entry) async {
    final String? text = await IpGeo.instance.lookup(_ipPart(entry));
    if (!mounted) return;
    setState(() {
      _geo[entry] = (text == null || text.isEmpty) ? '归属地未知' : text;
      _geoLoading.remove(entry);
    });
  }

  
  String _decorate(String entry, String? geo) {
    if (geo == null) return '查询归属地…';
    final int? n = _cidrCount(entry);
    return n == null ? geo : '$geo · 网段内 $n 个地址';
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
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
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
                        style: const TextStyle(fontSize: 14),
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
                          child: Text('网段',
                              style: TextStyle(
                                  fontSize: 9.5, color: cs.onSurfaceVariant)),
                        ),
                      ),
                  ],
                ),
                
                
                
                
                Row(
                  children: <Widget>[
                    if (_geoLoading.contains(ip)) ...<Widget>[
                      SizedBox(
                        width: 9,
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
                            fontSize: 10.5, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 17),
            visualDensity: VisualDensity.compact,
            tooltip: '编辑',
            onPressed: _busy ? null : () => _editBanEntry(index, ip),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17),
            visualDensity: VisualDensity.compact,
            tooltip: '删除',
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
      Formatter.showToast('IP 或网段格式不对：$v', isError: true);
      AppLog.instance.op('黑名单[添加]被拒：$v（格式不合法）',
          level: 'ERROR', scope: _server?.logScope);
      return;
    }
    final List<String> list = _banDraft.entries;
    if (list.contains(v)) {
      Formatter.showToast('名单里已经有 $v');
      return;
    }
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(
        bannedIps: QbIpFilter.joinEntries(QbIpFilter.addEntry(list, v)),
      );
      _banInput.clear();
    });
    AppLog.instance.act('服务器设置', '黑名单[添加]：$v',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');
  }

  
  Future<void> _editBanEntry(int index, String old) async {
    final String? v = await _promptText(
      title: '编辑黑名单条目',
      label: 'IP 或网段',
      help: '支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\n'
          '确定后只改本地草稿，点「保存黑名单」才下发。当前值：$old',
    );
    if (v == null) {
      AppLog.instance.act('服务器设置', '黑名单[编辑]·取消', target: old);
      return;
    }
    final String nv = v.trim();
    if (!QbIpFilter.isValidEntry(nv)) {
      Formatter.showToast('IP 或网段格式不对：$nv', isError: true);
      AppLog.instance.op('黑名单[编辑]被拒：$nv（格式不合法）',
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
    AppLog.instance.act('服务器设置', '黑名单[编辑]：$old → $nv',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');
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
    AppLog.instance.act('服务器设置', '黑名单[删除]：$ip',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');
  }

  
  Future<void> _bulkEditBanList() async {
    final int before = _banDraft.count;
    final String? text = await _promptMultiline(
      title: '批量编辑黑名单',
      initial: _banDraft.bannedIps,
      help: '每行一条，支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\n'
          '确定后整份替换本地草稿，再点「保存黑名单」下发。',
    );
    if (text == null) {
      AppLog.instance.act('服务器设置', '黑名单[批量编辑]·取消');
      return;
    }
    final List<String> lines = QbIpFilter.splitEntries(text);
    final List<String> bad =
        lines.where((String e) => !QbIpFilter.isValidEntry(e)).toList();
    if (bad.isNotEmpty) {
      Formatter.showToast('有 ${bad.length} 行格式不对，例如 ${bad.first}',
          isError: true);
      AppLog.instance.op(
          '黑名单[批量编辑]被拒：${bad.length} 行格式不合法（例 ${bad.first}）',
          level: 'ERROR',
          scope: _server?.logScope);
      return;
    }
    if (lines.length > QbIpFilter.maxEntries) {
      Formatter.showToast('最多 ${QbIpFilter.maxEntries} 条', isError: true);
      return;
    }
    setState(() {
      _banTouched = true;
      _banDraft = _banDraft.copyWith(bannedIps: QbIpFilter.joinEntries(lines));
      _banShowAll = false;
    });
    AppLog.instance.act('服务器设置', '黑名单[批量编辑]',
        target: _server?.name, detail: '$before 条 → ${lines.length} 条（未保存）');
  }

  
  Future<void> _saveBanList() async {
    final QbIpFilter? base = _banLoaded;
    final QbIpFilter next = _banDraft;
    await _run(
      '黑名单[保存]',
      '黑名单已保存（${next.count} 条）',
      '保存黑名单失败',
      () => _qb!.setIpFilter(next, base: base),
      after: () => _banTouched = false,
      detail: base == null ? '${next.count} 条' : next.diffSummary(base),
    );
  }

  
  
  
  
  Widget _prefsErrorNotice() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: AppTheme.iconSize, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '没能读取这台服务器的设置，下面的数字与开关暂不可信'
              '（${_prefsError ?? ''}）。点右上角刷新重试。',
              style: TextStyle(fontSize: 12, color: cs.error),
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
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(help, style: const TextStyle(fontSize: 10)),
              ),
            TextField(
              controller: c,
              maxLines: 8,
              minLines: 5,
              style: const TextStyle(fontSize: 13),
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

  

  Widget _group({
    required String title,
    required List<Widget> children,
    String? help,
  }) {
    return Theme(
      
      
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        clipBehavior: Clip.antiAlias,
        initiallyExpanded: false,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        children: <Widget>[
          if (help != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(help, style: const TextStyle(fontSize: 10)),
            ),
          ...children,
        ],
      ),
    );
  }

  
  
  
  
  
  
  
  Widget _switchRow(
    String label,
    bool value,
    ValueChanged<bool>? onChanged, {
    String? sub,
  }) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: sub == null
          ? null
          : Text(sub, style: const TextStyle(fontSize: 10)),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: _prefsLoaded ? onChanged : null,
      ),
    );
  }

  
  
  
  Widget _kbRow(
    String label,
    TextEditingController c, {
    String? prefKey,
  }) =>
      _textRow(label, c, numeric: true, suffix: 'KB/S', prefKey: prefKey);

  Widget _textRow(
    String label,
    TextEditingController c, {
    bool numeric = false,
    String? suffix,
    String? help,
    String? prefKey,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: const TextStyle(fontSize: 15)),
                if (help != null)
                  Text(help, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: c,
              maxLength: AppTheme.maxLenGeneral,
              buildCounter: AppTheme.noCounter,
              keyboardType:
                  numeric ? TextInputType.number : TextInputType.text,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                
                
                hintText: prefKey != null && !_prefsLoaded ? '--' : null,
              ),
              
              onChanged: prefKey == null
                  ? null
                  : (String _) => setState(() => _touched.add(prefKey)),
            ),
          ),
          if (suffix != null) ...<Widget>[
            const SizedBox(width: 4),
            Text(suffix, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _changeButton(
    String label,
    String okMsg,
    String failMsg,
    Future<void> Function() act, {
    String? detail,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        child: ElevatedButton(
          onPressed: _busy
              ? null
              : () => _run(label, okMsg, failMsg, act, detail: detail),
          child: Text(S.change, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _actionRow({required VoidCallback onAdd, required VoidCallback onDelete}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _busy ? null : onDelete,
              child: Text(S.delete, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: _busy ? null : onAdd,
              child: Text(S.add, style: const TextStyle(fontSize: 12)),
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
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(help, style: const TextStyle(fontSize: 10)),
              ),
            TextField(
              controller: c,
              maxLength: AppTheme.maxLenGeneral,
              buildCounter: AppTheme.noCounter,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
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
