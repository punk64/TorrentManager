# -*- coding: utf-8 -*-
"""trackers + peers 页国际化批量替换"""
import io

def sub(p, pairs, imp=True):
    src = io.open(p, encoding='utf-8').read()
    n = 0
    for old, new in pairs:
        if old in src:
            src = src.replace(old, new); n += 1
        else:
            print('MISS %s: %r' % (p.split('/')[-1], old[:76].replace('\n', '\\n')))
    if imp and "import '../../utils/i18n.dart';" not in src:
        if "import '../../utils/strings.dart';" in src:
            src = src.replace("import '../../utils/strings.dart';",
                              "import '../../utils/i18n.dart';\nimport '../../utils/strings.dart';", 1)
    io.open(p, 'w', encoding='utf-8').write(src)
    print('%s: %d/%d' % (p.split('/')[-1], n, len(pairs)))

sub('lib/pages/torrent_info_trackers_page.dart', [
  ("""            '这是私有种子（Private Torrent）\\n'
            '请保持 DHT / PEX / LSD 关闭 —— 它们会绕过 Tracker 广播本种子，'
            '可能导致 passkey 泄露并被站点封禁账号。',""",
   """            L.t('这是私有种子（Private Torrent）\\n'
            '请保持 DHT / PEX / LSD 关闭 —— 它们会绕过 Tracker 广播本种子，'
            '可能导致 passkey 泄露并被站点封禁账号。'),"""),
  ("Text('DHT / PEX / LSD 说明',", "Text(L.t('DHT / PEX / LSD 说明'),"),
  ("Text('仅 Transmission 显示为条目',", "Text(L.t('仅 Transmission 显示为条目'),"),
  ("tip('DHT', 'DHT · 分布式哈希表',", "tip('DHT', L.t('DHT · 分布式哈希表'),"),
  ("'无 Tracker 时也能通过 DHT 网络找到 Peer；私有种子必须关闭。',",
   "L.t('无 Tracker 时也能通过 DHT 网络找到 Peer；私有种子必须关闭。'),"),
  ("tip('PEX', 'PEX · Peer 交换',", "tip('PEX', L.t('PEX · Peer 交换'),"),
  ("'与已连接的 Peer 互相交换彼此的 Peer 列表；私有种子必须关闭。',",
   "L.t('与已连接的 Peer 互相交换彼此的 Peer 列表；私有种子必须关闭。'),"),
  ("tip('LSD', 'LSD · 本地发现',", "tip('LSD', L.t('LSD · 本地发现'),"),
  ("'在局域网内广播发现同一资源的设备；私有种子必须关闭。',",
   "L.t('在局域网内广播发现同一资源的设备；私有种子必须关闭。'),"),
  ("'$realCount 个 Tracker',",
   "L.pick('$realCount 个 Tracker', '$realCount trackers'),"),
  ("'· ⚠ $_badCount 个异常',",
   "L.pick('· ⚠ $_badCount 个异常', '· ⚠ $_badCount errors'),"),
  ("? '${e.label} · 建议关闭'", "? L.pick('${e.label} · 建议关闭', '${e.label} · disable recommended')"),
  ("_showChart ? '收起分布图' : 'Tracker 分布图（做种 / 下载者对比）',",
   "_showChart ? L.t('收起分布图') : L.t('Tracker 分布图（做种 / 下载者对比）'),"),
  ("return (0, '工作中');", "return (0, L.t('工作中'));"),
  ("return (1, '更新中');", "return (1, L.t('更新中'));"),
  ("return (2, '不可用');", "return (2, L.t('不可用'));"),
  ("return (3, '未联系');", "return (3, L.t('未联系'));"),
  ("return (3, '未启用');", "return (3, L.t('未启用'));"),
  ("return (3, '未知');", "return (3, L.t('未知'));"),
  ("if (t['isBackup'] == true) return (3, '备用');",
   "if (t['isBackup'] == true) return (3, L.t('备用'));"),
  ("return (0, '活动中');", "return (0, L.t('活动中'));"),
  ("return (1, '排队');", "return (1, L.t('排队'));"),
  ("return (1, '等待');", "return (1, L.t('等待'));"),
  ("return (3, '未活动');", "return (3, L.t('未活动'));"),
  ("nextAnnounce = diff > 0 ? '下次汇报 $diff 秒后' : '下次汇报 等待中';",
   "nextAnnounce = diff > 0 ? L.pick('下次汇报 $diff 秒后', 'Next announce in ${diff}s') : L.pick('下次汇报 等待中', 'Next announce pending');"),
  ("_stat('做种', '$seeds'),", "_stat(L.t('做种'), '$seeds'),"),
  ("_stat('下载者', '$leechs'),", "_stat(L.t('下载者'), '$leechs'),"),
  ("_stat('已完成', '$downloaded'),", "_stat(L.t('已完成'), '$downloaded'),"),
  ("_stat('层级', '$tier'),", "_stat(L.t('层级'), '$tier'),"),
  ("isQb ? (t['msg']?.toString().isNotEmpty == true ? t['msg'].toString() : '成功 ✓') : '成功 ✓',",
   "isQb ? (t['msg']?.toString().isNotEmpty == true ? t['msg'].toString() : L.t('成功 ✓')) : L.t('成功 ✓'),"),
  ("UiDialogs.showToast('${S.trkCopied}（passkey 已打码）');",
   "UiDialogs.showToast('${S.trkCopied}${L.pick('（passkey 已打码）', ' (passkey masked)')}');"),
  ("""AppLog.instance.op('修改 Tracker：$original → ${_oneLine(result)}'""",
   """AppLog.instance.op(L.pick('修改 Tracker：$original → ${_oneLine(result)}', 'Tracker edited: $original → ${_oneLine(result)}')"""),
  ("""AppLog.instance.op('添加 Tracker：${_oneLine(result)}'""",
   """AppLog.instance.op(L.pick('添加 Tracker：${_oneLine(result)}', 'Tracker added: ${_oneLine(result)}')"""),
  ("""AppLog.instance.op('修改 Tracker：$original → ${_oneLine(urls.first)}'""",
   """AppLog.instance.op(L.pick('修改 Tracker：$original → ${_oneLine(urls.first)}', 'Tracker edited: $original → ${_oneLine(urls.first)}')"""),
  ("""AppLog.instance.op('添加 Tracker：${_oneLine(result)}'""",
   """AppLog.instance.op(L.pick('添加 Tracker：${_oneLine(result)}', 'Tracker added: ${_oneLine(result)}')"""),
  ("""AppLog.instance.error('Tracker 操作失败（${editing ? '修改' : '添加'}）：'""",
   """AppLog.instance.error(L.pick('Tracker 操作失败（${editing ? '修改' : '添加'}）：', 'Tracker operation failed (${editing ? 'edit' : 'add'}): ')"""),
  ("AppLog.instance.op('删除 Tracker：$url（${t.name} · ${s.name}）',",
   "AppLog.instance.op(L.pick('删除 Tracker：$url（${t.name} · ${s.name}）', 'Tracker removed: $url (${t.name} · ${s.name})'),"),
  ("AppLog.instance.error('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}',",
   "AppLog.instance.error(L.pick('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}', 'Failed to remove tracker $url · ${Formatter.safeErr(e)}'),"),
])

sub('lib/pages/torrent_info_peers_page.dart', [
  ("UiDialogs.showToast('仅 qBittorrent 支持封禁 Peer', isError: true);",
   "UiDialogs.showToast(L.t('仅 qBittorrent 支持封禁 Peer'), isError: true);"),
  ("""AppLog.instance.op('封禁 Peer：$target'""",
   """AppLog.instance.op(L.pick('封禁 Peer：$target', 'Peer banned: $target')"""),
  ("""AppLog.instance.error('封禁 Peer 失败：$target · ${Formatter.safeErr(e)}',""",
   """AppLog.instance.error(L.pick('封禁 Peer 失败：$target · ${Formatter.safeErr(e)}', 'Failed to ban peer $target · ${Formatter.safeErr(e)}'),"""),
  ("UiDialogs.showToast('仅 qBittorrent 支持添加 Peer', isError: true);",
   "UiDialogs.showToast(L.t('仅 qBittorrent 支持添加 Peer'), isError: true);"),
  ("title: Text('添加 Peer', style: TextStyle(fontSize: af(context, 14))),",
   "title: Text(L.t('添加 Peer'), style: TextStyle(fontSize: af(context, 14))),"),
  ("Text('每行一个，格式 IP:端口（最多 10 个）',",
   "Text(L.t('每行一个，格式 IP:端口（最多 10 个）'),"),
  ("UiDialogs.showToast('格式无效：$v', isError: true);",
   "UiDialogs.showToast(L.pick('格式无效：$v', 'Invalid format: $v'), isError: true);"),
  ("if (mounted) UiDialogs.showToast('已添加 ${peers.length} 个 Peer');",
   "if (mounted) UiDialogs.showToast(L.pick('已添加 ${peers.length} 个 Peer', '${peers.length} peers added'));"),
  ("child: Text('暂无 Peer 数据', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('暂无 Peer 数据'), style: TextStyle(fontSize: af(context, 12))),"),
  ("text: '${ctrl.peers.length} 个 Peer',",
   "text: L.pick('${ctrl.peers.length} 个 Peer', '${ctrl.peers.length} peers'),"),
  ("text: ' · 下载中 ',", "text: L.t(' · 下载中 '),"),
  ("text: ' · 对其上传 ',", "text: L.t(' · 对其上传 '),"),
  ("label: Text('添加 Peer', style: TextStyle(fontSize: af(context, 10))),",
   "label: Text(L.t('添加 Peer'), style: TextStyle(fontSize: af(context, 10))),"),
  ("message: '切换升序 / 降序',", "message: L.t('切换升序 / 降序'),"),
  ("if (connection.isNotEmpty) _dCell('连接', connection),",
   "if (connection.isNotEmpty) _dCell(L.t('连接'), connection),"),
  ("if (encrypted) _dCell('加密', '✓'),", "if (encrypted) _dCell(L.t('加密'), '✓'),"),
  ("if (utp) _dCell('传输', 'uTP'),", "if (utp) _dCell(L.t('传输'), 'uTP'),"),
  ("if (incoming) _dCell('方向', '入站'),", "if (incoming) _dCell(L.t('方向'), L.t('入站')),"),
  ("_dCell('对其分享率', ratio.toStringAsFixed(2)),", "_dCell(L.t('对其分享率'), ratio.toStringAsFixed(2)),"),
  ("_dCell('相关度', '${(relevance * 100).toStringAsFixed(0)}%'),",
   "_dCell(L.t('相关度'), '${(relevance * 100).toStringAsFixed(0)}%'),"),
  ("'正在提供 $files',", "L.pick('正在提供 $files', 'offering $files'),"),
  ("return '按${S.fieldProgress}排序';",
   "return L.pick('按${S.fieldProgress}排序', 'By ${S.fieldProgress}');"),
  ("return '按${S.fieldDlSpeed}排序';",
   "return L.pick('按${S.fieldDlSpeed}排序', 'By ${S.fieldDlSpeed}');"),
  ("return '按${S.fieldUpSpeed}排序';",
   "return L.pick('按${S.fieldUpSpeed}排序', 'By ${S.fieldUpSpeed}');"),
  ("return '按${S.fieldIp}排序';",
   "return L.pick('按${S.fieldIp}排序', 'By ${S.fieldIp}');"),
  ("return _asc ? '从慢到快' : '从快到慢';",
   "return _asc ? L.t('从慢到快') : L.t('从快到慢');"),
  ("return _asc ? '从慢到快' : '从快到慢';",
   "return _asc ? L.t('从慢到快') : L.t('从快到慢');"),
  ("return _asc ? '从少到多' : '从多到少';",
   "return _asc ? L.t('从少到多') : L.t('从多到少');"),
  ("return _asc ? '正序' : '倒序';",
   "return _asc ? L.t('正序') : L.t('倒序');"),
])
