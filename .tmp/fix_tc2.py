# -*- coding: utf-8 -*-
"""torrent_controller.dart 第二批替换"""
import io

p = 'lib/controllers/torrent_controller.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("""      AppLog.instance.op(
        '操作失败：${_selectedNames()}'
        ' ｜ 服务器 ${serverCtrl.current.value?.name ?? '-'}'
        ' ｜ ${error.value}',
        level: 'ERROR',""",
   """      AppLog.instance.op(
        '${LogT.opFail(_selectedNames(), serverCtrl.current.value?.name ?? '-')}'
        ' ｜ ${error.value}',
        level: 'ERROR',"""),
  ("""    return '${names.take(limit).join('、')} 等 ${names.length} 个';""",
   """    return S.namesAndMore(names.take(limit).join('、'), names.length);"""),
  ("""      AppLog.instance.op('暂停 $n 个种子：${_selectedNames()}'
          '（服务器：${s.name} · ${s.isQbittorrent ? 'qB' : 'TR'}）',
          scope: s.logScope);""",
   """      AppLog.instance.op(
          LogT.opPauseResume(true, n, _selectedNames(), s.name, s.isQbittorrent),
          scope: s.logScope);"""),
  ("""      AppLog.instance.op('恢复 $n 个种子：${_selectedNames()}'
          '（服务器：${s.name} · ${s.isQbittorrent ? 'qB' : 'TR'}）',
          scope: s.logScope);""",
   """      AppLog.instance.op(
          LogT.opPauseResume(false, n, _selectedNames(), s.name, s.isQbittorrent),
          scope: s.logScope);"""),
  ("""            AppLog.instance.op('删除种子：有 $skipped 个缺少 Transmission '
                '任务 ID，已跳过（实际删除 $deleted 个）',
                scope: s.logScope);""",
   """            AppLog.instance.op(
                LogT.deleteSkipTrId(skipped, deleted),
                scope: s.logScope);"""),
  ("""        AppLog.instance.op('删除种子 ${chosen.length} 个'
            '${plan.subs.isEmpty ? '' : ' + 辅种 ${plan.subs.length} 个'}'
            '${plan.deleteFiles ? '（同时删除本地文件）' : '（仅移除任务）'}',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.deleteDone(chosen.length, plan.subs.isEmpty ? '' : ' + 辅种 ${plan.subs.length} 个', plan.deleteFiles),
            scope: s.logScope);"""),
  ("""      AppLog.instance.op(
        '编辑失败（${hashes.length} 个种子）：${NetError.describe(e)}',
        level: 'ERROR',
        scope: scopeAtStart,
      );""",
   """      AppLog.instance.op(
        LogT.editFail(hashes.length, NetError.describe(e)),
        level: 'ERROR',
        scope: scopeAtStart,
      );"""),
  ("""        AppLog.instance.op(
            '设置分类 → ${category.isEmpty ? '（空=未分类）' : category}'
            '（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setCategory(
                category.isEmpty ? L.t('（空=未分类）') : category, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '${append ? '追加' : '设置'}标签 → ${tags.isEmpty ? '（清空）' : tags.join(',')}'
            '（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setTags(append,
                tags.isEmpty ? L.t('（清空）') : tags.join(','), hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '设置限速 → 下载 ${dlKb ?? '-'} KB/s · 上传 ${upKb ?? '-'} KB/s'
            '（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setLimits('${dlKb ?? '-'}', '${upKb ?? '-'}', hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '修改保存路径 → $path（${move ? '同时移动文件' : '仅改指向'}'
            ' · ${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setPath(path, move, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '${value ? '开启' : '关闭'}强制做种（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.toggleForceSeed(value, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '${target ? '开启' : '关闭'}顺序下载（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.toggleSequential(target, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '${target ? '开启' : '关闭'}首尾块优先（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.toggleFirstLast(target, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '${value ? '开启' : '关闭'}超级做种（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.toggleSuperSeed(value, hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '设置分享限制 → 分享率 ${ratioLimit ?? '-'} · 做种时限 '
            '${seedingTimeMin ?? '-'} 分钟（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setShareLimits('${ratioLimit ?? '-'}', '${seedingTimeMin ?? '-'}', hashes.length),
            scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '设置队列位置 → $position（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setQueuePos('$position', hashes.length),
            scope: s.logScope);"""),
  ("""      AppLog.instance.op('添加 Peer：${peers.join(' | ')}',
          scope: s.logScope);""",
   """      AppLog.instance.op(LogT.addPeers(peers.join(' | ')),
          scope: s.logScope);"""),
  ("""      AppLog.instance.op('重命名文件：$oldPath → $newName（${t.name}）',
          scope: s.logScope);""",
   """      AppLog.instance.op(LogT.renameFile(oldPath, newName, t.name),
          scope: s.logScope);"""),
  ("""      AppLog.instance.op(
          '${value ? '开启' : '关闭'}遵循全局限速（${hashes.length} 个种子）',
          scope: s.logScope);""",
   """      AppLog.instance.op(
          LogT.toggleHonorLimits(value, hashes.length),
          scope: s.logScope);"""),
  ("""        AppLog.instance.op(
            '设置带宽优先级 → $priority（${hashes.length} 个种子）',
            scope: s.logScope);""",
   """        AppLog.instance.op(
            LogT.setPriority('$priority', hashes.length),
            scope: s.logScope);"""),
  ("AppLog.instance.op('重命名种子 → $name', scope: s.logScope);",
   "AppLog.instance.op(LogT.renameTorrent(name), scope: s.logScope);"),
  ("""        AppLog.instance.error('详情定点刷新失败：${NetError.describe(e)}',
            scope: serverCtrl.current.value?.logScope);""",
   """        AppLog.instance.error(
            LogT.detailRefreshFail(NetError.describe(e)),
            scope: serverCtrl.current.value?.logScope);"""),
  ("""      AppLog.instance.view(
        '种子详情[${t.name}] 已刷新：文件 ${f.length} · 用户 ${p.length} · Tracker ${tk.length}'
        '${fresh == null ? '（未取到新状态，沿用列表快照）' : ''}'
        ' ｜ 用时 ${ServerController.secs(sw.elapsed)}',
        key: '详情:$targetHash:refresh',
        scope: serverCtrl.current.value?.logScope,
      );""",
   """      AppLog.instance.view(
        '${LogT.detailRefreshed(t.name, f.length, p.length, tk.length, ServerController.secs(sw.elapsed))}'
        '${fresh == null ? L.t('（未取到新状态，沿用列表快照）') : ''}',
        key: '详情:$targetHash:refresh',
        scope: serverCtrl.current.value?.logScope,
      );"""),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS tc2: %r' % old[:76].replace('\n', '\\n'))
io.open(p, 'w', encoding='utf-8').write(src)
print('torrent_controller pass2:', n, '/', len(pairs))
