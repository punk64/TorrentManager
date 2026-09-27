# -*- coding: utf-8 -*-
"""torrent_info_overview_page.dart 国际化批量替换"""
import io

p = 'lib/pages/torrent_info_overview_page.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("static const String _kChecking = '校验中';",
   "static String get _kChecking => L.t('校验中');"),
  ("_metric('连接', t.activePeers < 0 ? '-' : '${t.activePeers}'),",
   "_metric(L.t('连接'), t.activePeers < 0 ? '-' : '${t.activePeers}'),"),
  ("_metric('做种', '${t.numComplete}'),", "_metric(L.t('做种'), '${t.numComplete}'),"),
  ("_metric('下载', '${t.numIncomplete}'),", "_metric(L.t('下载'), '${t.numIncomplete}'),"),
  ("if (at == null) return '正在获取…';", "if (at == null) return L.t('正在获取…');"),
  ("if (sec <= 1) return '刚刚更新 · 每 3 秒自动刷新';",
   "if (sec <= 1) return L.pick('刚刚更新 · 每 3 秒自动刷新', 'Just updated · auto-refresh every 3s');"),
  ("return '$sec 秒前更新 · 每 3 秒自动刷新';",
   "return L.pick('$sec 秒前更新 · 每 3 秒自动刷新', 'Updated ${sec}s ago · auto-refresh every 3s');"),
  ("label: '继续',", "label: L.t('继续'),"),
  (".act('种子详情', '按钮[继续]', target: t.name);",
   ".act('种子详情', L.t('按钮[继续]'), target: t.name);"),
  ("_run(t, _ctrl.resumeSelected, '已继续');",
   "_run(t, _ctrl.resumeSelected, L.t('已继续'));"),
  ("label: '暂停',", "label: L.t('暂停'),"),
  (".act('种子详情', '按钮[暂停]', target: t.name);",
   ".act('种子详情', L.t('按钮[暂停]'), target: t.name);"),
  ("_run(t, _ctrl.pauseSelected, '已暂停');",
   "_run(t, _ctrl.pauseSelected, L.t('已暂停'));"),
  ("label: checking ? '$_kChecking…' : '重新校验',",
   "label: checking ? '${L.t('校验中')}…' : L.t('重新校验'),"),
  ("label: '重新汇报',", "label: L.t('重新汇报'),"),
  ("'校验进度',", "L.t('校验进度'),"),
  ("<String>['本次会话 ↓', Formatter.setSize(sessionDl)],",
   "<String>[L.t('本次会话 ↓'), Formatter.setSize(sessionDl)],"),
  ("<String>['本次会话 ↑', Formatter.setSize(sessionUp)],",
   "<String>[L.t('本次会话 ↑'), Formatter.setSize(sessionUp)],"),
  ("<String>['可获取量', Formatter.setSize(desired)],",
   "<String>[L.t('可获取量'), Formatter.setSize(desired)],"),
  ("<String>['Web 做种', '$webSeeds'],", "<String>[L.t('Web 做种'), '$webSeeds'],"),
  ("'分块 ${pieceCount ?? states.length}'", "L.pick('分块 ${pieceCount ?? states.length}', 'Pieces ${pieceCount ?? states.length}')"),
  ("_legendCell(PieceHeatmap.cDone, '已完成'),", "_legendCell(PieceHeatmap.cDone, L.t('已完成')),"),
  ("_legendCell(PieceHeatmap.cActive, '下载中'),", "_legendCell(PieceHeatmap.cActive, L.t('下载中')),"),
  ("_legendCell(PieceHeatmap.cMissing, '空缺'),", "_legendCell(PieceHeatmap.cMissing, L.t('空缺')),"),
  ("label: '遵循全局限速',", "label: L.t('遵循全局限速'),"),
  ("'遵循全局限速',", "L.t('遵循全局限速'),"),
  ("chip('跟随全局', -2, current < -1),", "chip(L.t('跟随全局'), -2, current < -1),"),
  ("chip('自定义', 0, customShown),", "chip(L.t('自定义'), 0, customShown),"),
  ("chip('不限制', -1, current == -1 && !customShown),", "chip(L.t('不限制'), -1, current == -1 && !customShown),"),
  ("child: Text('内容路径', style: TextStyle(fontSize: af(context, 11))),",
   "child: Text(L.t('内容路径'), style: TextStyle(fontSize: af(context, 11))),"),
  ("child: Text('队列位置', style: TextStyle(fontSize: af(context, 11))),",
   "child: Text(L.t('队列位置'), style: TextStyle(fontSize: af(context, 11))),"),
  ("cap.isQb ? '第 ${t.priority} 位' : '第 ${t.priority + 1} 位',",
   "cap.isQb ? L.pick('第 ${t.priority} 位', '#${t.priority}') : L.pick('第 ${t.priority + 1} 位', '#${t.priority + 1}'),"),
  ("_queueBtn(context, cs, Icons.vertical_align_top, '置顶', 'top'),",
   "_queueBtn(context, cs, Icons.vertical_align_top, L.t('置顶'), 'top'),"),
  ("_queueBtn(context, cs, Icons.arrow_upward, '上移', 'up'),",
   "_queueBtn(context, cs, Icons.arrow_upward, L.t('上移'), 'up'),"),
  ("_queueBtn(context, cs, Icons.arrow_downward, '下移', 'down'),",
   "_queueBtn(context, cs, Icons.arrow_downward, L.t('下移'), 'down'),"),
  ("_queueBtn(context, cs, Icons.vertical_align_bottom, '沉底', 'bottom'),",
   "_queueBtn(context, cs, Icons.vertical_align_bottom, L.t('沉底'), 'bottom'),"),
  ("AppLog.instance.act('种子详情', '队列[$tip]', target: t.name);",
   "AppLog.instance.act('种子详情', L.pick('队列[$tip]', 'Queue[$tip]'), target: t.name);"),
  ("_run(t, () => _ctrl.queueMoveSelected(where), '已$tip');",
   "_run(t, () => _ctrl.queueMoveSelected(where), L.pick('已$tip', '$tip done'));"),
  ("'带宽优先级',", "L.t('带宽优先级'),"),
  ("child: Text('带宽优先级', style: TextStyle(fontSize: af(context, 11))),",
   "child: Text(L.t('带宽优先级'), style: TextStyle(fontSize: af(context, 11))),"),
  ("chip('高', 1),", "chip(L.t('高'), 1),"),
  ("chip('普通', 0),", "chip(L.t('普通'), 0),"),
  ("chip('低', -1),", "chip(L.t('低'), -1),"),
  ("<String>['创建时间', Formatter.setDate(createdOn)],",
   "<String>[L.t('创建时间'), Formatter.setDate(createdOn)],"),
  ("<String>['最后见到', Formatter.setDate(lastSeen)],",
   "<String>[L.t('最后见到'), Formatter.setDate(lastSeen)],"),
  ("<String>['做种时长', Formatter.setTime(t.newSeedingTime)],",
   "<String>[L.t('做种时长'), Formatter.setTime(t.newSeedingTime)],"),
  ("<String>['最近活动', Formatter.setLastActivity(t.newLastActivity)],",
   "<String>[L.t('最近活动'), Formatter.setLastActivity(t.newLastActivity)],"),
  ("if (createdBy != null) _kvCopy('创建工具', createdBy, maxLines: 2),",
   "if (createdBy != null) _kvCopy(L.t('创建工具'), createdBy, maxLines: 2),"),
  ("_kv('连接数', nbLimit != null && nbLimit > 0 ? '$nbConn / 上限 $nbLimit' : '$nbConn'),",
   "_kv(L.t('连接数'), nbLimit != null && nbLimit > 0 ? L.pick('$nbConn / 上限 $nbLimit', '$nbConn / limit $nbLimit') : '$nbConn'),"),
  ("_kv('连接上限', '$trMaxPeers'),", "_kv(L.t('连接上限'), '$trMaxPeers'),"),
  ("if (e.value != '未标记' && !cand.contains(e.value)) cand.add(e.value);",
   "if (e.value != L.t('未标记') && !cand.contains(e.value)) cand.add(e.value);"),
  ("UiDialogs.showToast('已开始校验 ${t.name}（进度见上方）');",
   "UiDialogs.showToast(L.pick('已开始校验 ${t.name}（进度见上方）', 'Recheck started for ${t.name} (see progress above)'));"),
  ("AppLog.instance.act('种子详情', '按钮[重新校验]', target: t.name);",
   "AppLog.instance.act('种子详情', L.t('按钮[重新校验]'), target: t.name);"),
  ("AppLog.instance.act('种子详情', '按钮[重新汇报]', target: t.name);",
   "AppLog.instance.act('种子详情', L.t('按钮[重新汇报]'), target: t.name);"),
  ("AppLog.instance.act('种子详情', '按钮[删除]·取消', target: t.name);",
   "AppLog.instance.act('种子详情', L.t('按钮[删除]·取消'), target: t.name);"),
  ("""    AppLog.instance.act('种子详情', '按钮[删除]',
        target: '${t.name}（含文件 ${opt.deleteFiles ? '是' : '否'}）');""",
   """    AppLog.instance.act('种子详情', L.t('按钮[删除]'),
        target: '${t.name}（${L.pick('含文件', 'with files')} ${opt.deleteFiles ? L.t('是') : L.t('否')}）');"""),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS ov: %r' % old[:76].replace('\n', '\\n'))
if "import '../../utils/i18n.dart';" not in src:
    if "import '../../utils/strings.dart';" in src:
        src = src.replace("import '../../utils/strings.dart';",
                          "import '../../utils/i18n.dart';\nimport '../../utils/strings.dart';", 1)
    else:
        import re
        m = re.search(r"import '[^']+';\n", src)
        src = src[:m.end()] + "import '../../utils/i18n.dart';\n" + src[m.end():]
io.open(p, 'w', encoding='utf-8').write(src)
print('overview:', n, '/', len(pairs))
