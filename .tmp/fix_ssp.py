# -*- coding: utf-8 -*-
"""server_setting_page.dart 页面替换"""
import io

p = 'lib/pages/server_setting_page.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("return (e == null || e.isEmpty) ? '未能在服务器上建立会话' : e;",
   "return (e == null || e.isEmpty) ? S.sessionNotEstablished : e;"),
  ("AppLog.instance.net('服务器设置：未能建立会话 —— $reason',",
   "AppLog.instance.net(LogT.sessionFail(reason),"),
  ("AppLog.instance.net('读取服务器偏好失败：${NetError.describe(e)}',",
   "AppLog.instance.net(LogT.prefsLoadFail(NetError.describe(e)),"),
  ("title: Text(name.isEmpty ? '服务器设置' : '$name · 服务器设置'),",
   "title: Text(S.serverSettingsTitle(name)),"),
  ("""              AppLog.instance.act('服务器设置', 'AppBar[刷新]',
                  target: _server?.name, detail: '重开会话 + 重拉偏好 + 分类标签');""",
   """              AppLog.instance.act('服务器设置', L.t('AppBar[刷新]'),
                  target: _server?.name, detail: LogT.appbarRefreshDetail());"""),
  ("title: '限速设置',", "title: L.t('限速设置'),"),
  ("_sectionTitle('普通限速', onChange: () => _run(\n            '全局限速[更改]',",
   "_sectionTitle(L.t('普通限速'), onChange: () => _run(\n            LogT.prefChanged(L.t('全局限速')),"),
  ("""            detail:
                '上行 ${_kbText(_upLimit)} KB/s · 下行 ${_kbText(_dlLimit)} KB/s',""",
   "            detail: S.kbPair(_kbText(_upLimit), _kbText(_dlLimit)),"),
  ("child: _numCell('上传限速', _upLimit,\n                  prefKey: PrefKey.upLimit, unit: 'KB/S'),",
   "child: _numCell(L.t('上传限速'), _upLimit,\n                  prefKey: PrefKey.upLimit, unit: 'KB/S'),"),
  ("child: _numCell('下载限速', _dlLimit,\n                  prefKey: PrefKey.dlLimit, unit: 'KB/S'),",
   "child: _numCell(L.t('下载限速'), _dlLimit,\n                  prefKey: PrefKey.dlLimit, unit: 'KB/S'),"),
  ("_sectionTitle('备用限速', onChange: () => _run(\n            '备用限速[更改]',",
   "_sectionTitle(L.t('备用限速'), onChange: () => _run(\n            LogT.prefChanged(L.t('备用限速')),"),
  ("""            detail:
                '上行 ${_kbText(_altUpLimit)} KB/s · 下行 ${_kbText(_altDlLimit)} KB/s',""",
   "            detail: S.kbPair(_kbText(_altUpLimit), _kbText(_altDlLimit)),"),
  ("'开关[启用备用限速]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(S.setEnableAltLimit, v),"),
  ("child: _numCell('上传限速', _altUpLimit,\n                  prefKey: 'alt_up_limit', unit: 'KB/S'),",
   "child: _numCell(L.t('上传限速'), _altUpLimit,\n                  prefKey: 'alt_up_limit', unit: 'KB/S'),"),
  ("child: _numCell('下载限速', _altDlLimit,\n                  prefKey: 'alt_dl_limit', unit: 'KB/S'),",
   "child: _numCell(L.t('下载限速'), _altDlLimit,\n                  prefKey: 'alt_dl_limit', unit: 'KB/S'),"),
  ("title: '管理分类',", "title: L.t('管理分类'),"),
  ("child: Text('未分类', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('未分类'), style: TextStyle(fontSize: af(context, 12))),"),
  ("      label: '类别名称',", "      label: L.t('类别名称'),"),
  ("      '分类[新增]：${name.trim()}',", "      LogT.prefAdded(L.t('分类'), name.trim()),"),
  ("detail: '改前 ${_categories.length} 个（点「更改」才提交）',",
   "detail: LogT.countBeforeCommit(_categories.length),"),
  ("      '分类[删除]：${_selectedCategories.join('、')}',",
   "      LogT.prefRemoved(L.t('分类'), _selectedCategories.join('、')),"),
  ("      detail: '改前 ${_categories.length} 个',",
   "      detail: LogT.countBefore(_categories.length),"),
  ("title: '管理标签',", "title: L.t('管理标签'),"),
  ("child: Text('无标签', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('无标签'), style: TextStyle(fontSize: af(context, 12))),"),
  ("await _promptText(title: S.add, label: '标签名称', help: S.setAddNewLineHelp);",
   "await _promptText(title: S.add, label: L.t('标签名称'), help: S.setAddNewLineHelp);"),
  ("      '标签[新增]：${name.trim()}',", "      LogT.prefAdded(L.t('标签'), name.trim()),"),
  ("      detail: '改前 ${_tags.length} 个',",
   "      detail: LogT.countBefore(_tags.length),"),
  ("      '标签[删除]：${_selectedTags.join('、')}',",
   "      LogT.prefRemoved(L.t('标签'), _selectedTags.join('、')),"),
  ("      detail: '改前 ${_tags.length} 个',",
   "      detail: LogT.countBefore(_tags.length),"),
  ("        title: '默认保存路径',", "        title: L.t('默认保存路径'),"),
  ("_pathDropdownField('默认保存路径', _savePath),",
   "_pathDropdownField(L.t('默认保存路径'), _savePath),"),
  ("            '保存路径[更改]',", "            LogT.prefChanged(L.t('保存路径')),"),
  ("            detail: '路径 ${_savePath.text.trim()}',",
   "            detail: LogT.detailPath(_savePath.text.trim()),"),
  ("        title: '临时保存路径',", "        title: L.t('临时保存路径'),"),
  ("'开关[启用临时保存路径]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(S.setEnableTempPath, v),"),
  ("_pathDropdownField('临时路径', _tempPath),",
   "_pathDropdownField(L.t('临时路径'), _tempPath),"),
  ("            '临时路径[更改]',", "            LogT.prefChanged(L.t('临时路径')),"),
  ("            detail: '路径 ${_tempPath.text.trim()}',",
   "            detail: LogT.detailPath(_tempPath.text.trim()),"),
  ("        title: '设置队列限制',", "        title: L.t('设置队列限制'),"),
  ("'开关[启用队列限制]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(S.setEnableQueueLimit, v),"),
  ("child: _numCell('最大活动上传数', _maxActiveUp,",
   "child: _numCell(L.t('最大活动上传数'), _maxActiveUp,"),
  ("child: _numCell('最大活动下载数', _maxActiveDl,",
   "child: _numCell(L.t('最大活动下载数'), _maxActiveDl,"),
  ("child: _numCell('最大活动种子数', _maxActiveTorrents,",
   "child: _numCell(L.t('最大活动种子数'), _maxActiveTorrents,"),
  ("            '队列限制[更改]',", "            LogT.prefChanged(L.t('队列限制')),"),
  ("""            detail: '上传 ${_kbText(_maxActiveUp)} / 下载 '
                '${_kbText(_maxActiveDl)}'
                '${_supports(PrefKey.maxActiveTorrents) ? ' / 种子 ${_kbText(_maxActiveTorrents)}' : ''}',""",
   """            detail: S.queueDetail(
                _kbText(_maxActiveUp),
                _kbText(_maxActiveDl),
                _supports(PrefKey.maxActiveTorrents)
                    ? _kbText(_maxActiveTorrents)
                    : null),"""),
  ("        title: '设置做种限制',", "        title: L.t('设置做种限制'),"),
  ("summary: '比率 ${_kbText(_maxRatio)}',",
   "summary: L.pick('比率 ${_kbText(_maxRatio)}', 'Ratio ${_kbText(_maxRatio)}'),"),
  ("child: _numCell('最大分享比率', _maxRatio, prefKey: PrefKey.maxRatio),",
   "child: _numCell(L.t('最大分享比率'), _maxRatio, prefKey: PrefKey.maxRatio),"),
  ("""child: _numCell('最长做种时间', _maxSeedingTime,
            prefKey: PrefKey.maxSeedingTime, unit: '分'),""",
   """child: _numCell(L.t('最长做种时间'), _maxSeedingTime,
            prefKey: PrefKey.maxSeedingTime, unit: L.t('分')),"""),
  ("""child: _numCell('非活动做种时间', _maxInactiveSeedingTime,
            prefKey: PrefKey.maxInactiveSeedingTime, unit: '分'),""",
   """child: _numCell(L.t('非活动做种时间'), _maxInactiveSeedingTime,
            prefKey: PrefKey.maxInactiveSeedingTime, unit: L.t('分')),"""),
  ("            '做种限制[更改]',", "            LogT.prefChanged(L.t('做种限制')),"),
  ("""            detail: '比率 ${_kbText(_maxRatio)} · 非活动 '
                '${_kbText(_maxInactiveSeedingTime)}'
                '${_supports(PrefKey.maxSeedingTime) ? ' · 做种 ${_kbText(_maxSeedingTime)}' : ''}',""",
   """            detail: S.seedDetail(
                _kbText(_maxRatio),
                _kbText(_maxInactiveSeedingTime),
                _supports(PrefKey.maxSeedingTime)
                    ? _kbText(_maxSeedingTime)
                    : null),"""),
  ("        title: '设置连接限制',", "        title: L.t('设置连接限制'),"),
  ("summary: '全局 ${_kbText(_maxConnec)} · 单种 ${_kbText(_maxConnecPerTorrent)}',",
   "summary: L.pick('全局 ${_kbText(_maxConnec)} · 单种 ${_kbText(_maxConnecPerTorrent)}', 'Global ${_kbText(_maxConnec)} · per-torrent ${_kbText(_maxConnecPerTorrent)}'),"),
  ("child: _numCell('全局最大连接数', _maxConnec,",
   "child: _numCell(L.t('全局最大连接数'), _maxConnec,"),
  ("child: _numCell('单种最大连接数', _maxConnecPerTorrent,",
   "child: _numCell(L.t('单种最大连接数'), _maxConnecPerTorrent,"),
  ("child: _numCell('全局上传连接数', _maxUpConnec,",
   "child: _numCell(L.t('全局上传连接数'), _maxUpConnec,"),
  ("child: _numCell('单种上传连接数', _maxUpConnecPerTorrent,",
   "child: _numCell(L.t('单种上传连接数'), _maxUpConnecPerTorrent,"),
  ("            '连接限制[更改]',", "            LogT.prefChanged(L.t('连接限制')),"),
  ("""            detail: '全局 ${_kbText(_maxConnec)} / 单种 '
                '${_kbText(_maxConnecPerTorrent)} / 单种连接 '
                '${_kbText(_maxUpConnecPerTorrent)}'
                '${_supports(PrefKey.maxUploads) ? ' / 连接 ${_kbText(_maxUpConnec)}' : ''}',""",
   """            detail: S.connDetail(
                _kbText(_maxConnec),
                _kbText(_maxConnecPerTorrent),
                _kbText(_maxUpConnecPerTorrent),
                _supports(PrefKey.maxUploads) ? _kbText(_maxUpConnec) : null),"""),
  ("        title: '自动种子管理',", "        title: L.t('自动种子管理'),"),
  ("'开关[自动种子管理]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(L.t('自动种子管理'), v),"),
  ("'开关[预分配磁盘空间]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(L.t('预分配磁盘空间'), v),"),
  ("'开关[未完成文件加扩展名]${v ? ' → 开' : ' → 关'}',",
   "LogT.prefSwitch(L.t('未完成文件加扩展名'), v),"),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS ssp: %r' % old[:80].replace('\n', '\\n'))
if "import '../utils/i18n.dart';" not in src:
    src = src.replace("import '../utils/strings.dart';",
                      "import '../utils/i18n.dart';\nimport '../utils/log_text.dart';\nimport '../utils/strings.dart';", 1)
io.open(p, 'w', encoding='utf-8').write(src)
print('server_setting pass1:', n, '/', len(pairs))
