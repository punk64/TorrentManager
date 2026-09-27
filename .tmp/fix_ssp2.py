# -*- coding: utf-8 -*-
"""server_setting_page.dart 第二批：IP 过滤 / 黑名单区"""
import io

p = 'lib/pages/server_setting_page.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("""        summary: _prefsLoaded
            ? '${_prefInt(PrefKey.blocklistSize) ?? 0} 条'
            : '',""",
   """        summary: _prefsLoaded
            ? S.entriesCount(_prefInt(PrefKey.blocklistSize) ?? 0)
            : '',"""),
  ("""        help: 'Transmission 只能整份**订阅**黑名单文件（blocklist-url），\\n'
            '由服务端自行下载解析；它没有逐条增删的接口。',""",
   """        help: L.t('Transmission 只能整份**订阅**黑名单文件（blocklist-url），\\n'
            '由服务端自行下载解析；它没有逐条增删的接口。'),"""),
  ("""          _switchRow(
            '启用 IP 过滤',
            _prefBool(PrefKey.ipFilterEnabled),
            (bool v) => _run(
              '开关[启用 IP 过滤]${v ? ' → 开' : ' → 关'}',
              v ? '已启用 IP 过滤' : '已关闭 IP 过滤',
              '设置 IP 过滤失败',""",
   """          _switchRow(
            L.t('启用 IP 过滤'),
            _prefBool(PrefKey.ipFilterEnabled),
            (bool v) => _run(
              LogT.prefSwitch(L.t('启用 IP 过滤'), v),
              S.ipFilterOn(v),
              S.setIpFilterFail,"""),
  ("            sub: '关掉后订阅来的黑名单不再生效',",
   "            sub: L.t('关掉后订阅来的黑名单不再生效'),"),
  ("_pathField('订阅地址', _blocklistUrl, prefKey: PrefKey.blocklistUrl),",
   "_pathField(L.t('订阅地址'), _blocklistUrl, prefKey: PrefKey.blocklistUrl),"),
  ("""          _changeButton(
            '黑名单订阅[更改]',
            '黑名单订阅已更新',
            '设置黑名单订阅失败',""",
   """          _changeButton(
            LogT.prefChanged(L.t('黑名单订阅')),
            S.blocklistSubUpdated,
            S.setBlocklistSubFail,"""),
  ("            detail: '地址 ${_blocklistUrl.text.trim()}',",
   "            detail: LogT.detailAddr(_blocklistUrl.text.trim()),"),
  ("""                _prefsLoaded
                    ? '当前屏蔽 ${_prefInt(PrefKey.blocklistSize) ?? 0} 条'
                    : '当前屏蔽 —',""",
   """                _prefsLoaded
                    ? S.currentBlocked(_prefInt(PrefKey.blocklistSize) ?? 0)
                    : S.currentBlockedDash,"""),
  ("""        help: '服务器（qBittorrent）上被封禁的来源 IP / 网段，每行一条、支持 CIDR。\\n'
            '上面两个开关即时生效；名单改动点「保存黑名单」后一次性下发。',""",
   """        help: L.t('服务器（qBittorrent）上被封禁的来源 IP / 网段，每行一条、支持 CIDR。\\n'
            '上面两个开关即时生效；名单改动点「保存黑名单」后一次性下发。'),"""),
  ("""          _switchRow(
            '启用 IP 过滤',
            _banDraft.enabled,
            (bool v) => _run(
              '开关[启用 IP 过滤]${v ? ' → 开' : ' → 关'}',
              v ? '已启用 IP 过滤' : '已关闭 IP 过滤',
              '设置 IP 过滤失败',""",
   """          _switchRow(
            L.t('启用 IP 过滤'),
            _banDraft.enabled,
            (bool v) => _run(
              LogT.prefSwitch(L.t('启用 IP 过滤'), v),
              S.ipFilterOn(v),
              S.setIpFilterFail,"""),
  ("            sub: '关掉后这份名单不再生效（内容保留）',",
   "            sub: L.t('关掉后这份名单不再生效（内容保留）'),"),
  ("""          _switchRow(
            '同时过滤 Tracker 连接',
            _banDraft.filterTrackers,
            (bool v) => _run(
              '开关[过滤 Tracker 连接]${v ? ' → 开' : ' → 关'}',
              v ? '已同时过滤 Tracker 连接' : '已只过滤普通连接',
              '设置 IP 过滤失败',""",
   """          _switchRow(
            L.t('同时过滤 Tracker 连接'),
            _banDraft.filterTrackers,
            (bool v) => _run(
              LogT.prefSwitch(L.t('过滤 Tracker 连接'), v),
              S.trackerFilterOn(v),
              S.setIpFilterFail,"""),
  ("            sub: '连 tracker 也走同一份名单',",
   "            sub: L.t('连 tracker 也走同一份名单'),"),
  ("""    return d == 0
        ? '名单有改动，未保存'
        : '名单有改动（${d > 0 ? '+' : ''}$d 条），未保存';""",
   """    return d == 0
        ? S.dirtyUnsaved
        : S.dirtyCount(d);"""),
  ("child: Text('批量编辑', style: TextStyle(fontSize: af(context, 11.5))),",
   "child: Text(L.t('批量编辑'), style: TextStyle(fontSize: af(context, 11.5))),"),
  ("child: Text('未读取到服务器设置', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('未读取到服务器设置'), style: TextStyle(fontSize: af(context, 12))),"),
  ("child: Text('名单为空', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('名单为空'), style: TextStyle(fontSize: af(context, 12))),"),
  ("child: Text('显示全部（还有 ${list.length - shown} 条）',",
   "child: Text(L.pick('显示全部（还有 ${list.length - shown} 条）', 'Show all (${list.length - shown} more)'),"),
  ("    return '查询归属地…';", "    return S.geoSearching;"),
  ("_geo[entry] = (text == null || text.isEmpty) ? '归属地未知' : text;",
   "_geo[entry] = (text == null || text.isEmpty) ? S.geoUnknown : text;"),
  ("    if (geo == null) return '查询归属地…';", "    if (geo == null) return S.geoSearching;"),
  ("    return n == null ? geo : '$geo · 网段内 $n 个地址';",
   "    return n == null ? geo : S.geoRange(geo, n);"),
  ("""                          child: Text('网段',""",
   """                          child: Text(L.t('网段'),"""),
  ("tooltip: '编辑',", "tooltip: L.t('编辑'),"),
  ("tooltip: '删除',", "tooltip: L.t('删除'),"),
  ("UiDialogs.showToast('IP 或网段格式不对：$v', isError: true);",
   "UiDialogs.showToast(S.badIpFormat(v), isError: true);"),
  ("AppLog.instance.op('黑名单[添加]被拒：$v（格式不合法）',",
   "AppLog.instance.op(LogT.prefRejected(L.t('黑名单'), v),"),
  ("UiDialogs.showToast('名单里已经有 $v');",
   "UiDialogs.showToast(S.dupIp(v));"),
  ("""AppLog.instance.act('服务器设置', '黑名单[添加]：$v',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');""",
   """AppLog.instance.act('服务器设置', LogT.blacklistAdded(v),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));"""),
  ("      title: '编辑黑名单条目',", "      title: L.t('编辑黑名单条目'),"),
  ("      label: 'IP 或网段',", "      label: L.t('IP 或网段'),"),
  ("""      help: '支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\\n'
          '确定后只改本地草稿，点「保存黑名单」才下发。当前值：$old',""",
   """      help: L.pick('支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\\n'
          '确定后只改本地草稿，点「保存黑名单」才下发。当前值：$old',
          'Supports a single IP (1.2.3.4) or CIDR range (1.2.3.0/24).\\n'
          'OK updates the local draft only; it goes live when you tap "Save blocklist". Current: $old'),"""),
  ("AppLog.instance.act('服务器设置', '黑名单[编辑]·取消', target: old);",
   "AppLog.instance.act('服务器设置', L.t('黑名单[编辑]·取消'), target: old);"),
  ("UiDialogs.showToast('IP 或网段格式不对：$nv', isError: true);",
   "UiDialogs.showToast(S.badIpFormat(nv), isError: true);"),
  ("AppLog.instance.op('黑名单[编辑]被拒：$nv（格式不合法）',",
   "AppLog.instance.op(LogT.prefRejected(L.t('黑名单'), nv),"),
  ("""AppLog.instance.act('服务器设置', '黑名单[编辑]：$old → $nv',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');""",
   """AppLog.instance.act('服务器设置', LogT.blacklistEdited(old, nv),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));"""),
  ("""AppLog.instance.act('服务器设置', '黑名单[删除]：$ip',
        target: _server?.name, detail: '草稿 ${_banDraft.count} 条（未保存）');""",
   """AppLog.instance.act('服务器设置', LogT.blacklistDeleted(ip),
        target: _server?.name, detail: LogT.banDraftDetail(_banDraft.count));"""),
  ("      title: '批量编辑黑名单',", "      title: L.t('批量编辑黑名单'),"),
  ("""      help: '每行一条，支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\\n'
          '确定后整份替换本地草稿，再点「保存黑名单」下发。',""",
   """      help: L.pick('每行一条，支持单个 IP（1.2.3.4）与网段（1.2.3.0/24）。\\n'
          '确定后整份替换本地草稿，再点「保存黑名单」下发。',
          'One entry per line; a single IP (1.2.3.4) or CIDR range (1.2.3.0/24).\\n'
          'OK replaces the whole local draft; tap "Save blocklist" to apply.'),"""),
  ("AppLog.instance.act('服务器设置', '黑名单[批量编辑]·取消');",
   "AppLog.instance.act('服务器设置', L.t('黑名单[批量编辑]·取消'));"),
  ("""      UiDialogs.showToast('有 ${bad.length} 行格式不对，例如 ${bad.first}',
          isError: true);""",
   """      UiDialogs.showToast(S.banRowsBad(bad.length, bad.first),
          isError: true);"""),
  ("""      AppLog.instance.op(
          '黑名单[批量编辑]被拒：${bad.length} 行格式不合法（例 ${bad.first}）',
          level: 'ERROR',
          scope: _server?.logScope);""",
   """      AppLog.instance.op(
          LogT.prefRejected(L.t('黑名单批量编辑'),
              '${bad.length} 行（例 ${bad.first}）'),
          level: 'ERROR',
          scope: _server?.logScope);"""),
  ("UiDialogs.showToast('最多 ${QbIpFilter.maxEntries} 条', isError: true);",
   "UiDialogs.showToast(S.banMaxRows(QbIpFilter.maxEntries), isError: true);"),
  ("""AppLog.instance.act('服务器设置', '黑名单[批量编辑]',
        target: _server?.name, detail: '$before 条 → ${lines.length} 条（未保存）');""",
   """AppLog.instance.act('服务器设置', L.t('黑名单[批量编辑]'),
        target: _server?.name, detail: S.rowsTransition(before, lines.length));"""),
  ("""    await _run(
      '黑名单[保存]',
      '黑名单已保存（${next.count} 条）',
      '保存黑名单失败',
      () => _qb!.setIpFilter(next, base: base),
      after: () => _banTouched = false,
      detail: base == null ? '${next.count} 条' : next.diffSummary(base),
    );""",
   """    await _run(
      LogT.prefChanged(L.t('黑名单')),
      S.blacklistSaved(next.count),
      L.t('保存黑名单失败'),
      () => _qb!.setIpFilter(next, base: base),
      after: () => _banTouched = false,
      detail: base == null ? S.banSaveDetail(next.count) : next.diffSummary(base),
    );"""),
  ("""            child: Text(
              '没能读取这台服务器的设置，下面的数字与开关暂不可信'
              '（${_prefsError ?? ''}）。点右上角刷新重试。',""",
   """            child: Text(
              S.loadFailHint(_prefsError ?? ''),"""),
  ("""        _pillButton(
            '保存黑名单',""",
   """        _pillButton(
            L.t('保存黑名单'),"""),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS ssp2: %r' % old[:80].replace('\n', '\\n'))
io.open(p, 'w', encoding='utf-8').write(src)
print('server_setting pass2:', n, '/', len(pairs))
