# -*- coding: utf-8 -*-
"""server_controller.dart 国际化批量替换"""
import io

p = 'lib/controllers/server_controller.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("ConnStage.handshake => '正在连接服务器…',", "ConnStage.handshake => L.t('正在连接服务器…'),"),
  ("ConnStage.loading => '正在获取种子列表…',", "ConnStage.loading => L.t('正在获取种子列表…'),"),
  ("""      AppLog.instance.op('解除挂起，恢复自动重试：${_nameOf(id)}',
            scope: LogScope(id, _nameOf(id)));""",
   """      AppLog.instance.op(LogT.resumeRetry(_nameOf(id)),
            scope: LogScope(id, _nameOf(id)));"""),
  ("AppLog.instance.op('手动刷新：解除全部服务器的挂起与退避');",
   "AppLog.instance.op(L.t('手动刷新：解除全部服务器的挂起与退避'));"),
  ("""      AppLog.instance.net('$why ｜ 已暂停该服务器的自动重试（${kind.name}）',
          scope: LogScope(id, _nameOf(id)));""",
   """      AppLog.instance.net(LogT.retrySuspended(why, kind.name),
          scope: LogScope(id, _nameOf(id)));"""),
  ("""      AppLog.instance.net(
          '$why ｜ 连续失败 $n 次，已挂起自动重试（${kind.name}）',
          scope: LogScope(id, _nameOf(id)));""",
   """      AppLog.instance.net(LogT.retryGaveUp(why, n, kind.name),
          scope: LogScope(id, _nameOf(id)));"""),
  ("""    AppLog.instance.net('$why ｜ 第 $n 次失败，${delay}s 后重试',
        scope: LogScope(id, _nameOf(id)));""",
   """    AppLog.instance.net(LogT.retryScheduled(why, n, delay),
        scope: LogScope(id, _nameOf(id)));"""),
  ("""    AppLog.instance.net('连接失败，立即重探局域网可达性：${_nameOf(id)}',
        scope: LogScope(id, _nameOf(id)));""",
   """    AppLog.instance.net(LogT.reconnectProbe(_nameOf(id)),
        scope: LogScope(id, _nameOf(id)));"""),
  ("""      AppLog.instance.op('连接恢复，已解除挂起：${_nameOf(id)}',
          scope: LogScope(id, _nameOf(id)));""",
   """      AppLog.instance.op(LogT.recovered(_nameOf(id)),
          scope: LogScope(id, _nameOf(id)));"""),
  ("""      AppLog.instance.view(
        '服务器卡片[${_nameOf(id)}] 连接中…（建连 / 登录）',
        key: '卡片:$id:connecting',""",
   """      AppLog.instance.view(
        LogT.cardConnecting(_nameOf(id)),
        key: '卡片:$id:connecting',"""),
  ("""    final String t = took == null ? '' : ' ｜ 用时 ${secs(took)}';
    AppLog.instance.view(
      sessionOnly
          ? '服务器卡片[${_nameOf(id)}] 会话已建立（先显示全局速率，种子统计随后）$t'
          : '服务器卡片[${_nameOf(id)}] 数据已获取'
              '$t ｜ 种子 ${torrentsOf(id).length} 个',
      key: sessionOnly ? '卡片:$id:session' : '卡片:$id:connected',""",
   """    final String t = took == null ? '' : ' ｜ 用时 ${secs(took)}';
    AppLog.instance.view(
      sessionOnly
          ? LogT.cardSessionOk(_nameOf(id), t)
          : LogT.cardDataOk(_nameOf(id), t, torrentsOf(id).length),
      key: sessionOnly ? '卡片:$id:session' : '卡片:$id:connected',"""),
  ("""    AppLog.instance.view(
      '服务器卡片[${_nameOf(id)}] 信息已刷新：$detail',
      key: '卡片:$id:refreshed',""",
   """    AppLog.instance.view(
      LogT.cardRefreshed(_nameOf(id), detail),
      key: '卡片:$id:refreshed',"""),
  ("""      AppLog.instance.net(
          api.isEmpty ? '${s.name} 版本号：$v' : '${s.name} 版本：$v（WebAPI $api）',
          scope: s.logScope,
      );""",
   """      AppLog.instance.net(
          LogT.cardVersion(s.name, v, api),
          scope: s.logScope,
      );"""),
  ("""      AppLog.instance.net('取版本号失败（不影响连接）：${NetError.describe(e)}',
          scope: s.logScope);""",
   """      AppLog.instance.net(LogT.versionFail(NetError.describe(e)),
          scope: s.logScope);"""),
  ("""    final String why = '登录失败：$reason';""",
   """    final String why = S.loginFailedWith(reason);"""),
  ("""          qb.lastLoginError ?? '登录失败：服务器拒绝了登录，请检查账号与密码',""",
   """          qb.lastLoginError ?? S.loginRejectedHint,"""),
  ("""          reportAuthFailure(
                s.id, r.reason ?? '服务器拒绝了登录，请检查账号与密码');""",
   """          reportAuthFailure(s.id, r.reason ?? S.loginRejectedHint);"""),
  ("""      final String held = at == null
          ? '未知'
          : '${DateTime.now().difference(at).inMilliseconds}ms';""",
   """      final String held = at == null
          ? L.t('未知')
          : '${DateTime.now().difference(at).inMilliseconds}ms';"""),
  ("""        AppLog.instance.warn(
          '手动刷新[${s.name}] 被跳过：已有一笔在飞（已持续 $held）',
          scope: s.logScope,
        );""",
   """        AppLog.instance.warn(
          LogT.skipInflight('手动刷新', s.name, held),
          scope: s.logScope,
        );"""),
  ("""        AppLog.instance.view(
          '服务器卡片[${s.name}] 轮询被跳过：已有一笔在飞（已持续 $held）',
          key: '卡片:${s.id}:inflight-skip',""",
   """        AppLog.instance.view(
          LogT.cardSkipInflight(s.name, held),
          key: '卡片:${s.id}:inflight-skip',"""),
  ("""                  : '登录失败：服务器拒绝了登录，请检查账号与密码'),""",
   """                  : S.loginRejectedHint),"""),
  ("""          reportAuthFailure(s.id, r.reason ?? '登录失败');""",
   """          reportAuthFailure(s.id, r.reason ?? S.loginFailed);"""),
  ("""          AppLog.instance.net(
              '${s.name}：路由切换中，本轮跳过（不判定为登录失败，下一轮重试）',
              scope: s.logScope);""",
   """          AppLog.instance.net(LogT.routeSwitching(s.name),
              scope: s.logScope);"""),
  ("""    AppLog.instance.net('网络已变化（连续两轮确认），重新探测局域网可达性',
        scope: cur.logScope);""",
   """    AppLog.instance.net(
        L.t('网络已变化（连续两轮确认），重新探测局域网可达性'),
        scope: cur.logScope);"""),
  ("""    const String why = '网络已断开（设备当前没有可用网络）';""",
   """    final String why = S.offlineNoNetwork;"""),
  ("""      AppLog.instance.net(
      n > 0
          ? '检测到断网：$n 台服务器标记为连接失败（网络恢复后会自动重试）'
          : '检测到断网（当前没有在线的服务器）',
    );""",
   """    AppLog.instance.net(
      n > 0
          ? LogT.offlineMarked(n)
          : L.t('检测到断网（当前没有在线的服务器）'),
    );"""),
  ("AppLog.instance.net('网络已恢复：解除退避 / 挂起，立即重试全部服务器');",
   "AppLog.instance.net(L.t('网络已恢复：解除退避 / 挂起，立即重试全部服务器'));"),
  ("AppLog.instance.op('添加服务器：${s.name}（${s.type}）', scope: s.logScope);",
   "AppLog.instance.op(LogT.serverAdded(s.name, s.type), scope: s.logScope);"),
  ("""    AppLog.instance.op('${i >= 0 ? '修改' : '添加'}服务器：${s.name}（${s.type}）',
        scope: s.logScope);""",
   """    AppLog.instance.op(LogT.serverUpsert(i >= 0, s.name, s.type),
        scope: s.logScope);"""),
  ("AppLog.instance.op('调整服务器排序：${s.name} → 第 ${at + 1} 位', scope: s.logScope);",
   "AppLog.instance.op(LogT.serverReordered(s.name, at + 1), scope: s.logScope);"),
  ("AppLog.instance.op('调整分组内服务器排序（本组 ${next.length} 台）');",
   "AppLog.instance.op(LogT.groupReordered(next.length));"),
  ("AppLog.instance.op('切换当前服务器：${s.name}（${s.type}）', scope: s.logScope);",
   "AppLog.instance.op(LogT.serverSwitched(s.name, s.type), scope: s.logScope);"),
  ("""      final String why = useLan
          ? '可达 → 该台此后走局域网'
          : (onLan
              ? '端口可达但身份校验未通过 → 该台此后走公网'
              : '不可达 → 该台此后走公网');
      AppLog.instance.view(
        '局域网探测[${s.name}] $why'
        '（非当前服务器，仅记录结论） ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',""",
   """      final String why = useLan
          ? L.t('可达 → 该台此后走局域网')
          : (onLan
              ? L.t('端口可达但身份校验未通过 → 该台此后走公网')
              : L.t('不可达 → 该台此后走公网'));
      AppLog.instance.view(
        LogT.lanProbeWhy(s.name, why, secs(sw.elapsed)),
        key: '局域网:${s.id}:result',"""),
  ("""      AppLog.instance.view(
        '局域网探测[${cur.name}] 端口可达，但身份校验未通过（不是同一台 Transmission）'
        ' → 仍走公网 ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',""",
   """      AppLog.instance.view(
        LogT.lanProbeNotSame(cur.name, secs(sw.elapsed)),
        key: '局域网:${s.id}:result',"""),
  ("AppLog.instance.net('局域网可达，已切换至局域网连接：${cur.name} (${target.baseUrl})',",
   "AppLog.instance.net(LogT.lanSwitched(cur.name, target.baseUrl),"),
  ("""      AppLog.instance.view(
        '局域网探测[${cur.name}] 可达 → 改走局域网 ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',""",
   """      AppLog.instance.view(
        LogT.lanProbeLan(cur.name, secs(sw.elapsed)),
        key: '局域网:${s.id}:result',"""),
  ("""      AppLog.instance.net(
          '未检测到局域网（${s.lanHost}:${s.lanPort} 连不上），回落到公网：${cur.name} (${target.baseUrl})',
          scope: cur.logScope);""",
   """      AppLog.instance.net(
          LogT.lanFallback(s.lanHost, s.lanPort, cur.name, target.baseUrl),
          scope: cur.logScope);"""),
  ("""      AppLog.instance.view(
        '局域网探测[${cur.name}] 不可达（${s.lanHost}:${s.lanPort}）→ 走公网'
        ' ｜ 用时 ${secs(sw.elapsed)}',
        key: '局域网:${s.id}:result',""",
   """      AppLog.instance.view(
        LogT.lanProbeWan(cur.name, s.lanHost, s.lanPort, secs(sw.elapsed)),
        key: '局域网:${s.id}:result',"""),
  ("""        AppLog.instance.net(
            '局域网身份校验跳过：未能取到 config-dir'
            '（公网 ${wan ?? '-'} / 局域网 ${lan ?? '-'}）',
            level: 'WARN',
            scope: s.logScope);""",
   """        AppLog.instance.net(
            LogT.lanIdentitySkip(wan ?? '-', lan ?? '-'),
            level: 'WARN',
            scope: s.logScope);"""),
  ("AppLog.instance.net('局域网身份校验通过（config-dir 一致：$lan）',",
   "AppLog.instance.net(LogT.lanIdentityOk(lan),"),
  ("""      AppLog.instance.net(
          '局域网地址指向的 Transmission 与公网不是同一台：'
          'config-dir 局域网=$lan ≠ 公网=$wan ⇒ 放弃走局域网，改用公网',
          level: 'ERROR',
          scope: s.logScope);""",
   """      AppLog.instance.net(
          LogT.lanIdentityMismatch(lan, wan),
          level: 'ERROR',
          scope: s.logScope);"""),
  ("""      AppLog.instance.net(
          '局域网身份校验失败（按同一台处理）：${Formatter.safeErr(e)}',
          level: 'WARN',
          scope: s.logScope);""",
   """      AppLog.instance.net(
          LogT.lanIdentityFailAssumed(Formatter.safeErr(e)),
          level: 'WARN',
          scope: s.logScope);"""),
  ("AppLog.instance.op('设置备份文件夹：${_logFileName(dir)}');",
   "AppLog.instance.op(LogT.backupDirSet(_logFileName(dir)));"),
  ("""        AppLog.instance.warn(
            '备份写入所选文件夹失败，改用应用私有目录：${Formatter.safeErr(e)}');""",
   """        AppLog.instance.warn(
            LogT.backupPrivateFallback(Formatter.safeErr(e)));"""),
  ("""    AppLog.instance.op(
        '导出备份（AES-256-GCM 加密）：${servers.length} 台 → ${_logFileName(path)}');""",
   """    AppLog.instance.op(
        LogT.backupExported(servers.length, _logFileName(path)));"""),
  ("dialogTitle: '保存备份副本',", "dialogTitle: L.t('保存备份副本'),"),
  ("AppLog.instance.op('导出备份副本：${_logFileName(out)}');",
   "AppLog.instance.op(LogT.backupCopyExported(_logFileName(out)));"),
  ("dialogTitle: '保存便携备份',", "dialogTitle: L.t('保存便携备份'),"),
  ("""    AppLog.instance.op(
        '导出便携备份（口令加密，含密码）：${servers.length} 台 → ${_logFileName(out)}');""",
   """    AppLog.instance.op(
        LogT.portableExported(servers.length, _logFileName(out)));"""),
  ("""    AppLog.instance.op(
        '导入便携备份（含密码）：文件 ${incoming.length} 台，新增 $added，覆盖 $updated');""",
   """    AppLog.instance.op(
        LogT.portableImported(incoming.length, added, updated));"""),
  ("""      throw const CryptoBoxException(
          '这不是本机导出的加密备份（内容不是有效的加密信封），已拒绝导入');""",
   """      throw CryptoBoxException(L.t(
          '这不是本机导出的加密备份（内容不是有效的加密信封），已拒绝导入'));"""),
  ("AppLog.instance.op('从备份恢复：文件含 ${local.length} 台，新增 $added 台');",
   "AppLog.instance.op(LogT.backupRestored(local.length, added));"),
  ("AppLog.instance.op('删除备份文件：${_logFileName(p)}');",
   "AppLog.instance.op(LogT.backupDeleted(_logFileName(p)));"),
  ("""    AppLog.instance.op(
        '${servers[i].hideAddress ? '隐藏' : '显示'}服务器地址：${servers[i].name}');""",
   """    AppLog.instance.op(
        LogT.hideAddress(servers[i].hideAddress, servers[i].name));"""),
  ("""    AppLog.instance.op(
        '${servers[i].hidePort ? '屏蔽' : '显示'}服务器端口：${servers[i].name}');""",
   """    AppLog.instance.op(
        LogT.hidePort(servers[i].hidePort, servers[i].name));"""),
  ("""    AppLog.instance.op(
        '${hide ? '隐藏' : '显示'}服务器地址与端口：${servers[i].name}');""",
   """    AppLog.instance.op(
        LogT.hideBoth(hide, servers[i].name));"""),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS sc: %r' % old[:80].replace('\n', '\\n'))
if "import '../utils/i18n.dart';" not in src:
    src = src.replace("import '../utils/app_log.dart';",
                      "import '../utils/app_log.dart';\nimport '../utils/i18n.dart';\nimport '../utils/log_text.dart';", 1)
io.open(p, 'w', encoding='utf-8').write(src)
print('server_controller:', n, '/', len(pairs))
