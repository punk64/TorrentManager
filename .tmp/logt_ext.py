# -*- coding: utf-8 -*-
"""LogT 扩展：controllers 日志函数"""
import io

p = 'lib/utils/log_text.dart'
src = io.open(p, encoding='utf-8').read()
add = '''
  static String retrySuspended(String why, String kind) => L.pick(
      '$why ｜ 已暂停该服务器的自动重试（$kind）',
      '$why | auto-retry paused for this server ($kind)');

  static String retryGaveUp(String why, int n, String kind) => L.pick(
      '$why ｜ 连续失败 $n 次，已挂起自动重试（$kind）',
      '$why | failed $n times in a row; auto-retry suspended ($kind)');

  static String retryScheduled(String why, int n, int delay) => L.pick(
      '$why ｜ 第 $n 次失败，${delay}s 后重试',
      '$why | attempt $n failed; retrying in ${delay}s');

  static String resumeRetry(String name) => L.pick(
      '解除挂起，恢复自动重试：$name',
      'Suspension lifted, auto-retry resumed: $name');

  static String reconnectProbe(String name) => L.pick(
      '连接失败，立即重探局域网可达性：$name',
      'Connection failed; re-probing LAN reachability now: $name');

  static String recovered(String name) => L.pick(
      '连接恢复，已解除挂起：$name', 'Connection recovered, suspension lifted: $name');

  static String cardConnecting(String name) => L.pick(
      '服务器卡片[$name] 连接中…（建连 / 登录）',
      'Server card[$name] connecting (connect / sign-in)');

  static String cardSessionOk(String name, String took) => L.pick(
      '服务器卡片[$name] 会话已建立（先显示全局速率，种子统计随后）$took',
      'Server card[$name] session established (global rates shown first, torrent stats follow)$took');

  static String cardDataOk(String name, String took, int count) => L.pick(
      '服务器卡片[$name] 数据已获取$took ｜ 种子 $count 个',
      'Server card[$name] data fetched$took | $count torrents');

  static String cardRefreshed(String name, String detail) => L.pick(
      '服务器卡片[$name] 信息已刷新：$detail',
      'Server card[$name] refreshed: $detail');

  static String cardVersion(String name, String v, String api) => L.pick(
      api.isEmpty ? '$name 版本号：$v' : '$name 版本：$v（WebAPI $api）',
      api.isEmpty ? '$name version: $v' : '$name version: $v (WebAPI $api)');

  static String versionFail(String err) => L.pick(
      '取版本号失败（不影响连接）：$err',
      'Failed to fetch version (connection unaffected): $err');

  static String connFailed(String why) =>
      L.pick('连接失败：$why', 'Connection failed: $why');

  static String manualRefreshAll(int n) => L.pick(
      '手动刷新全部服务器（$n 台）', 'Manual refresh of all servers ($n)');

  static String manualRetry(String name) =>
      L.pick('手动重试服务器：$name', 'Manual retry: $name');

  static String skipInflight(String kind, String name, String held) => L.pick(
      '$kind[$name] 被跳过：已有一笔在飞（已持续 $held）',
      '$kind[$name] skipped: one already in flight ($held)');

  static String cardSkipInflight(String name, String held) => L.pick(
      '服务器卡片[$name] 轮询被跳过：已有一笔在飞（已持续 $held）',
      'Server card[$name] poll skipped: one already in flight ($held)');

  static String routeSwitching(String name) => L.pick(
      '$name：路由切换中，本轮跳过（不判定为登录失败，下一轮重试）',
      '$name: route switching, skipped this round (not a sign-in failure; retry next round)');

  static String cardRoute(String name, bool lan) => L.pick(
      '服务器卡片[$name] 首笔请求路由：${lan ? '局域网' : '公网'}',
      'Server card[$name] first-request route: ${lan ? 'LAN' : 'WAN'}');

  static String serverAdded(String name, String type) => L.pick(
      '添加服务器：$name（$type）', 'Server added: $name ($type)');

  static String serverUpsert(bool edited, String name, String type) => L.pick(
      '${edited ? '修改' : '添加'}服务器：$name（$type）',
      'Server ${edited ? 'updated' : 'added'}: $name ($type)');

  static String serverDeleted(String name, bool wasCurrent) => L.pick(
      '删除服务器：$name${wasCurrent ? '（原为当前服务器，已清空种子视图）' : ''}',
      'Server deleted: $name${wasCurrent ? ' (was current; torrent view cleared)' : ''}');

  static String serverReordered(String name, int at) => L.pick(
      '调整服务器排序：$name → 第 $at 位',
      'Server reordered: $name → position $at');

  static String groupReordered(int n) => L.pick(
      '调整分组内服务器排序（本组 $n 台）',
      'Reordered servers within group ($n in group)');

  static String serverSwitched(String name, String type) => L.pick(
      '切换当前服务器：$name（$type）', 'Switched current server: $name ($type)');

  static String lanProbeStart(String name, String host, String port) => L.pick(
      '局域网探测[$name] 开始：$host:$port',
      'LAN probe[$name] start: $host:$port');

  static String lanProbeSuperseded(String name, String took) => L.pick(
      '局域网探测[$name] 结果已被更新的探测取代（本次结论作废）$took',
      'LAN probe[$name] superseded by a newer probe (result discarded)$took');

  static String lanProbeWhy(String name, String why, String took) => L.pick(
      '局域网探测[$name] $why（非当前服务器，仅记录结论） ｜ 用时 $took',
      'LAN probe[$name] $why (not the current server; conclusion recorded only) | took $took');

  static String lanProbeNotSame(String name, String took) => L.pick(
      '局域网探测[$name] 端口可达，但身份校验未通过（不是同一台 Transmission） → 仍走公网 ｜ 用时 $took',
      'LAN probe[$name] port reachable but identity check failed (not the same Transmission) → staying on WAN | took $took');

  static String lanProbeLan(String name, String took) => L.pick(
      '局域网探测[$name] 可达 → 改走局域网 ｜ 用时 $took',
      'LAN probe[$name] reachable → switching to LAN | took $took');

  static String lanProbeWan(String name, String host, String port, String took) =>
      L.pick('局域网探测[$name] 不可达（$host:$port）→ 走公网 ｜ 用时 $took',
          'LAN probe[$name] unreachable ($host:$port) → staying on WAN | took $took');

  static String lanSwitched(String name, String baseUrl) => L.pick(
      '局域网可达，已切换至局域网连接：$name ($baseUrl)',
      'LAN reachable, switched to LAN connection: $name ($baseUrl)');

  static String lanFallback(String host, String port, String name, String baseUrl) =>
      L.pick('未检测到局域网（$host:$port 连不上），回落到公网：$name ($baseUrl)',
          'No LAN detected ($host:$port unreachable); falling back to WAN: $name ($baseUrl)');

  static String lanIdentitySkip(String wan, String lan) => L.pick(
      '局域网身份校验跳过：未能取到 config-dir（公网 $wan / 局域网 $lan）',
      'LAN identity check skipped: config-dir unavailable (WAN $wan / LAN $lan)');

  static String lanIdentityOk(String lan) => L.pick(
      '局域网身份校验通过（config-dir 一致：$lan）',
      'LAN identity check passed (config-dir matches: $lan)');

  static String lanIdentityMismatch(String lan, String wan) => L.pick(
      '局域网地址指向的 Transmission 与公网不是同一台：config-dir 局域网=$lan ≠ 公网=$wan ⇒ 放弃走局域网，改用公网',
      'The LAN address points to a different Transmission than WAN: config-dir LAN=$lan ≠ WAN=$wan ⇒ abandoning LAN, using WAN');

  static String lanIdentityFailAssumed(String err) => L.pick(
      '局域网身份校验失败（按同一台处理）：$err',
      'LAN identity check failed (assuming same machine): $err');

  static String backupDirSet(String file) => L.pick(
      '设置备份文件夹：$file', 'Backup folder set: $file');

  static String backupPrivateFallback(String err) => L.pick(
      '备份写入所选文件夹失败，改用应用私有目录：$err',
      'Failed to write backup to the chosen folder; using app-private directory: $err');

  static String backupExported(int n, String path) => L.pick(
      '导出备份（AES-256-GCM 加密）：$n 台 → $path',
      'Backup exported (AES-256-GCM encrypted): $n servers → $path');

  static String backupCopyExported(String file) => L.pick(
      '导出备份副本：$file', 'Backup copy exported: $file');

  static String portableExported(int n, String path) => L.pick(
      '导出便携备份（口令加密，含密码）：$n 台 → $path',
      'Portable backup exported (passphrase-encrypted, includes passwords): $n servers → $path');

  static String portableImported(int n, int added, int updated) => L.pick(
      '导入便携备份（含密码）：文件 $n 台，新增 $added，覆盖 $updated',
      'Portable backup imported (with passwords): $n servers in file, $added added, $updated overwritten');

  static String backupRestored(int n, int added) => L.pick(
      '从备份恢复：文件含 $n 台，新增 $added 台',
      'Restored from backup: file contains $n servers, $added added');

  static String backupDeleted(String file) =>
      L.pick('删除备份文件：$file', 'Backup file deleted: $file');

  static String hideAddress(bool hidden, String name) => L.pick(
      '${hidden ? '隐藏' : '显示'}服务器地址：$name',
      'Server address ${hidden ? 'hidden' : 'shown'}: $name');

  static String hidePort(bool masked, String name) => L.pick(
      '${masked ? '屏蔽' : '显示'}服务器端口：$name',
      'Server port ${masked ? 'masked' : 'shown'}: $name');

  static String hideBoth(bool hidden, String name) => L.pick(
      '${hidden ? '隐藏' : '显示'}服务器地址与端口：$name',
      'Server address & port ${hidden ? 'hidden' : 'shown'}: $name');

  static String offlineMarked(int n) => L.pick(
      '检测到断网：$n 台服务器标记为连接失败（网络恢复后会自动重试）',
      'Network lost: $n servers marked as connection-failed (auto-retry when back online)');

  static String listVisible(bool foreground) => L.pick(
      foreground ? '种子列表页 进入前台 → 恢复自动取数' : '种子列表页 退到后台 → 停止自动取数',
      foreground ? 'Torrent list resumed → auto-fetch on' : 'Torrent list backgrounded → auto-fetch off');

  static String catCreateFail(String n, String p, String err) => L.pick(
      '创建分类「$n」${p.isEmpty ? '' : ' → $p'}：$err',
      'Category "$n" creation failed${p.isEmpty ? '' : ' → $p'}: $err');

  static String listCacheRender(String name, int n) => L.pick(
      '种子列表[$name] 先用缓存渲染 $n 条（真实数据随后覆盖）',
      'Torrent list[$name] rendering $n cached rows first (live data will overwrite)');

  static String listStart(String name) =>
      L.pick('种子列表[$name] 开始加载（全量）', 'Torrent list[$name] loading (full)');

  static String listFullReady(String name, int n, String took) => L.pick(
      '种子列表[$name] 全量 $n 条已就绪 ｜ 用时 $took',
      'Torrent list[$name] full $n rows ready | took $took');

  static String listDeltaApplied(String name, int n, String took) => L.pick(
      '种子列表[$name] 增量已应用：$n 条 ｜ 用时 $took',
      'Torrent list[$name] delta applied: $n rows | took $took');

  static String mergeFail(String hash, String err) => L.pick(
      '增量合并失败（$hash）：$err', 'Delta merge failed ($hash): $err');

  static String trParseFail(String hash, String err) => L.pick(
      'TR 种子解析失败（$hash）：$err', 'TR torrent parse failed ($hash): $err');

  static String opFail(String names, String server) => L.pick(
      '操作失败：$names ｜ 服务器 $server',
      'Operation failed: $names | server $server');

  static String opPauseResume(bool pause, int n, String names, String server, bool isQb) =>
      L.pick('${pause ? '暂停' : '恢复'} $n 个种子：$names（服务器：$server · ${isQb ? 'qB' : 'TR'}）',
          '${pause ? 'Paused' : 'Resumed'} $n torrents: $names (server: $server · ${isQb ? 'qB' : 'TR'})');

  static String deleteSkipTrId(int skipped, int deleted) => L.pick(
      '删除种子：有 $skipped 个缺少 Transmission 任务 ID，已跳过（实际删除 $deleted 个）',
      'Delete torrents: $skipped lacked Transmission task ids and were skipped ($deleted actually deleted)');

  static String forceRecheck(int n) =>
      L.pick('强制校验 $n 个种子', 'Force recheck of $n torrents');

  static String queueMove(String where) =>
      L.pick('队列移动 → $where', 'Queue move → $where');

  static String editFail(int n, String err) => L.pick(
      '编辑失败（$n 个种子）：$err', 'Edit failed ($n torrents): $err');

  static String setCategory(String category, int n) => L.pick(
      '设置分类 → $category（$n 个种子）',
      'Set category → $category ($n torrents)');

  static String setTags(bool append, String tags, int n) => L.pick(
      '${append ? '追加' : '设置'}标签 → $tags（$n 个种子）',
      '${append ? 'Appended' : 'Set'} tags → $tags ($n torrents)');

  static String setLimits(String dl, String up, int n) => L.pick(
      '设置限速 → 下载 $dl KB/s · 上传 $up KB/s（$n 个种子）',
      'Set limits → down $dl KB/s · up $up KB/s ($n torrents)');

  static String setPath(String path, bool move, int n) => L.pick(
      '修改保存路径 → $path（${move ? '同时移动文件' : '仅改指向'} · $n 个种子）',
      'Set save path → $path (${move ? 'moving files' : 'repoint only'} · $n torrents)');

  static String toggleForceSeed(bool value, int n) => L.pick(
      '${value ? '开启' : '关闭'}强制做种（$n 个种子）',
      'Force seeding ${value ? 'on' : 'off'} ($n torrents)');

  static String toggleSequential(bool value, int n) => L.pick(
      '${value ? '开启' : '关闭'}顺序下载（$n 个种子）',
      'Sequential download ${value ? 'on' : 'off'} ($n torrents)');

  static String toggleFirstLast(bool value, int n) => L.pick(
      '${value ? '开启' : '关闭'}首尾块优先（$n 个种子）',
      'First/last piece priority ${value ? 'on' : 'off'} ($n torrents)');

  static String toggleSuperSeed(bool value, int n) => L.pick(
      '${value ? '开启' : '关闭'}超级做种（$n 个种子）',
      'Super seeding ${value ? 'on' : 'off'} ($n torrents)');

  static String setShareLimits(String ratio, String minutes, int n) => L.pick(
      '设置分享限制 → 分享率 $ratio · 做种时限 $minutes 分钟（$n 个种子）',
      'Set share limits → ratio $ratio · seeding time $minutes min ($n torrents)');

  static String setQueuePos(String position, int n) => L.pick(
      '设置队列位置 → $position（$n 个种子）',
      'Set queue position → $position ($n torrents)');

  static String addPeers(String peers) =>
      L.pick('添加 Peer：$peers', 'Add peers: $peers');

  static String renameFile(String oldPath, String newName, String torrent) =>
      L.pick('重命名文件：$oldPath → $newName（$torrent）',
          'Rename file: $oldPath → $newName ($torrent)');

  static String toggleHonorLimits(bool value, int n) => L.pick(
      '${value ? '开启' : '关闭'}遵循全局限速（$n 个种子）',
      'Honor global limits ${value ? 'on' : 'off'} ($n torrents)');

  static String setPriority(String priority, int n) => L.pick(
      '设置带宽优先级 → $priority（$n 个种子）',
      'Set bandwidth priority → $priority ($n torrents)');

  static String renameTorrent(String name) =>
      L.pick('重命名种子 → $name', 'Rename torrent → $name');

  static String detailRefreshFail(String err) => L.pick(
      '详情定点刷新失败：$err', 'Detail refresh failed: $err');

  static String detailRefreshed(String name, int f, int p, int tk, String took) =>
      L.pick('种子详情[$name] 已刷新：文件 $f · 用户 $p · Tracker $tk ｜ 用时 $took',
          'Torrent detail[$name] refreshed: files $f · peers $p · trackers $tk | took $took');

  static String appearanceReset() => L.pick(
      '恢复默认外观（参数复位为出厂明亮档）',
      'Appearance reset to defaults (factory light profile)');

  static String themeMigrated() => L.pick(
      '主题迁移：已清理内置三档下残留的预设外观参数',
      'Theme migration: cleaned leftover preset appearance params under the built-in profiles');

  static String modeSwitched(bool dark) => L.pick(
      '切换主题：${dark ? '黑暗模式' : '明亮模式'}',
      'Theme switched: ${dark ? 'dark' : 'light'} mode');

  static String themeApplied(String name, String extra) => L.pick(
      '应用主题：$name$extra', 'Theme applied: $name$extra');

  static String customSaved(String name) =>
      L.pick('保存自定义主题：$name', 'Custom theme saved: $name');

  static String customOverwritten(String name) =>
      L.pick('覆盖更新自定义主题：$name', 'Custom theme overwritten: $name');

  static String customRenamed(String oldName, String name) => L.pick(
      '重命名自定义主题：$oldName → $name', 'Custom theme renamed: $oldName → $name');

  static String customDeleted(String name) =>
      L.pick('删除自定义主题：$name', 'Custom theme deleted: $name');

  static String customApplied(String name, String seed) => L.pick(
      '应用自定义主题：$name（seed $seed）', 'Custom theme applied: $name (seed $seed)');

  static String customImported(int added, int replaced) => L.pick(
      '导入自定义主题：新增 $added 套、覆盖 $replaced 套',
      'Custom themes imported: $added added, $replaced overwritten');

  static String sortChanged(String key, bool desc) => L.pick(
      '排序：$key · ${desc ? '降序' : '升序'}',
      'Sort: $key · ${desc ? 'descending' : 'ascending'}');

  static String sortDirChanged(bool desc) => L.pick(
      '排序方向：${desc ? '降序' : '升序'}',
      'Sort direction: ${desc ? 'descending' : 'ascending'}');

  static String siteMaskChanged(bool on) => L.pick(
      '站点打码：${on ? '开启' : '关闭'}',
      'Site masking: ${on ? 'on' : 'off'}');
}
'''
src = src.rstrip()
assert src.endswith('}')
src = src[:-1] + add
io.open(p, 'w', encoding='utf-8').write(src)
print('LogT now has', src.count('static String'), 'functions')
