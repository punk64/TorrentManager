# -*- coding: utf-8 -*-
"""server_setting_page.dart 国际化批量替换（含 LogT/S 扩展）"""
import io

# 1) LogT 追加
p = 'lib/utils/log_text.dart'
src = io.open(p, encoding='utf-8').read()
anchor = "  static String sortChanged(String key, bool desc)"
add = """  static String prefChanged(String x) =>
      L.pick('$x[更改]', '$x changed');

  static String prefSwitch(String x, bool v) => L.pick(
      '开关[$x]${v ? ' → 开' : ' → 关'}',
      'Switch[$x] → ${v ? 'on' : 'off'}');

  static String prefAdded(String x, String name) =>
      L.pick('$x[新增]：$name', '$x added: $name');

  static String prefRemoved(String x, String names) =>
      L.pick('$x[删除]：$names', '$x removed: $names');

  static String prefRejected(String x, String v) =>
      L.pick('$x被拒：$v（格式不合法）', '$x rejected: $v (invalid format)');

  static String countBefore(int n) =>
      L.pick('改前 $n 个', 'before: $n');

  static String countBeforeCommit(int n) => L.pick(
      '改前 $n 个（点「更改」才提交）',
      'before: $n (applied only after tapping Change)');

  static String detailPath(String p) =>
      L.pick('路径 $p', 'path $p');

  static String detailAddr(String a) =>
      L.pick('地址 $a', 'url $a');

  static String blacklistSaved(int n) => L.pick(
      '黑名单已保存（$n 条）', 'Blocklist saved ($n entries)');

  static String sessionFail(String reason) => L.pick(
      '服务器设置：未能建立会话 —— $reason',
      'Server settings: failed to establish a session — $reason');

  static String prefsLoadFail(String err) => L.pick(
      '读取服务器偏好失败：$err', 'Failed to load server preferences: $err');

  static String rowsTransition(int before, int after) => L.pick(
      '$before 条 → $after 条（未保存）',
      '$before → $after entries (unsaved)');

  static String banDraftDetail(int n) => L.pick(
      '草稿 $n 条（未保存）', 'draft $n entries (unsaved)');

  static String blacklistAdded(String v, int n) => L.pick(
      '黑名单[添加]：$v', 'Blocklist added: $v');

  static String blacklistEdited(String oldV, String nv) => L.pick(
      '黑名单[编辑]：$oldV → $nv', 'Blocklist edited: $oldV → $nv');

  static String blacklistDeleted(String ip) =>
      L.pick('黑名单[删除]：$ip', 'Blocklist removed: $ip');

  static String appbarRefreshDetail() => L.pick(
      '重开会话 + 重拉偏好 + 分类标签',
      'reopen session + reload prefs + categories/tags');

  static String logActLabel(String scope, String label) => label;
"""
src = src.replace(anchor, add + anchor)
io.open(p, 'w', encoding='utf-8').write(src)
print('LogT extended')

# 2) S 追加
p = 'lib/utils/strings.dart'
src = io.open(p, encoding='utf-8').read()
anchor = "  static String get offlineNoNetwork => L.t('网络已断开（设备当前没有可用网络）');"
add = anchor + '''
  static String get sessionNotEstablished => L.t('未能在服务器上建立会话');
  static String serverSettingsTitle(String name) => L.pick(
      name.isEmpty ? '服务器设置' : '$name · 服务器设置',
      name.isEmpty ? 'Server settings' : '$name · Server settings');
  static String kbPair(String up, String down) => L.pick(
      '上行 $up KB/s · 下行 $down KB/s', 'Up $up KB/s · Down $down KB/s');
  static String queueDetail(String up, String dl, String? torrents) => L.pick(
      torrents == null
          ? '上传 $up / 下载 $dl'
          : '上传 $up / 下载 $dl / 种子 $torrents',
      torrents == null
          ? 'up $up / down $dl'
          : 'up $up / down $dl / torrents $torrents');
  static String seedDetail(String ratio, String inactive, String? seeding) =>
      L.pick(seeding == null
              ? '比率 $ratio · 非活动 $inactive'
              : '比率 $ratio · 非活动 $inactive · 做种 $seeding',
          seeding == null
              ? 'ratio $ratio · inactive $inactive'
              : 'ratio $ratio · inactive $inactive · seeding $seeding');
  static String connDetail(String g, String per, String upPer, String? uploads) =>
      L.pick(uploads == null
              ? '全局 $g / 单种 $per / 单种连接 $upPer'
              : '全局 $g / 单种 $per / 单种连接 $upPer / 连接 $uploads',
          uploads == null
              ? 'global $g / per-torrent $per / per-torrent uploads $upPer'
              : 'global $g / per-torrent $per / per-torrent uploads $upPer / uploads $uploads');
  static String entriesCount(int n) => L.pick('$n 条', '$n entries');
  static String currentBlocked(int n) =>
      L.pick('当前屏蔽 $n 条', 'currently blocking $n');
  static String get currentBlockedDash => L.t('当前屏蔽 —');
  static String ipFilterOn(bool on) => L.pick(
      on ? '已启用 IP 过滤' : '已关闭 IP 过滤',
      on ? 'IP filtering enabled' : 'IP filtering disabled');
  static String get setIpFilterFail => L.t('设置 IP 过滤失败');
  static String trackerFilterOn(bool both) => L.pick(
      both ? '已同时过滤 Tracker 连接' : '已只过滤普通连接',
      both ? 'Tracker connections now filtered too' : 'Now filtering regular connections only');
  static String get blocklistSubUpdated => L.t('黑名单订阅已更新');
  static String get setBlocklistSubFail => L.t('设置黑名单订阅失败');
  static String get dirtyUnsaved => L.t('名单有改动，未保存');
  static String dirtyCount(int d) => L.pick(
      '名单有改动（${d > 0 ? '+' : ''}$d 条），未保存',
      'List modified (${d > 0 ? '+' : ''}$d entries), unsaved');
  static String bannedCount(int n) => L.pick('已封禁 $n 条', '$n banned');
  static String get bannedDash => L.t('已封禁 —');
  static String get geoSearching => L.t('查询归属地…');
  static String get geoUnknown => L.t('归属地未知');
  static String geoRange(String geo, int n) => L.pick(
      '$geo · 网段内 $n 个地址', '$geo · $n addresses in range');
  static String badIpFormat(String v) => L.pick(
      'IP 或网段格式不对：$v', 'Invalid IP or CIDR: $v');
  static String dupIp(String v) => L.pick('名单里已经有 $v', 'Already in the list: $v');
  static String banRowsBad(int n, String first) => L.pick(
      '有 $n 行格式不对，例如 $first', '$n rows have invalid format, e.g. $first');
  static String banMaxRows(int n) => L.pick('最多 $n 条', 'At most $n entries');
  static String rowsTransition(int before, int after) => L.pick(
      '$before 条 → $after 条（未保存）', '$before → $after entries (unsaved)');
  static String banSaveDetail(int n) => L.pick('$n 条', '$n entries');
  static String loadFailHint(String err) => L.pick(
      '没能读取这台服务器的设置，下面的数字与开关暂不可信'
          '（$err）。点右上角刷新重试。',
      'Could not load this server\'s settings; the numbers and switches below may be '
          'stale ($err). Tap refresh (top-right) to retry.');
  static String banSummary(int n, int? diff) => L.pick(
      diff == null || diff == 0 ? '$n 条' : '$n 条 · ${diff > 0 ? '+' : ''}$diff',
      diff == null || diff == 0 ? '$n entries' : '$n entries · ${diff > 0 ? '+' : ''}$diff');'''
assert anchor in src
src = src.replace(anchor, add)
io.open(p, 'w', encoding='utf-8').write(src)
print('S extended')
