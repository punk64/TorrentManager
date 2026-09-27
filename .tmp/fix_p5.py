# -*- coding: utf-8 -*-
"""批5：share/files/add/dialog/log_qb/log/server_list/torrent_list"""
import io

def sub(p, pairs, i18n=True):
    src = io.open(p, encoding='utf-8').read()
    n = 0
    for old, new in pairs:
        if old in src:
            src = src.replace(old, new); n += 1
        else:
            print('MISS %s: %r' % (p.split('/')[-1], old[:76].replace('\n', '\\n')))
    if i18n and "import '../utils/i18n.dart';" not in src:
        if "import '../utils/strings.dart';" in src:
            src = src.replace("import '../utils/strings.dart';",
                              "import '../utils/i18n.dart';\nimport '../utils/strings.dart';", 1)
    io.open(p, 'w', encoding='utf-8').write(src)
    print('%s: %d/%d' % (p.split('/')[-1], n, len(pairs)))

sub('lib/pages/share_page.dart', [
  ("title: Text('备份与恢复', style: TextStyle(fontSize: af(context, 15))),",
   "title: Text(L.t('备份与恢复'), style: TextStyle(fontSize: af(context, 15))),"),
  ("""                '本构建为纯本地版：备份保存在本机，'
                '如需迁移到其他设备请使用「导出 / 导入 JSON」。',""",
   """                L.t('本构建为纯本地版：备份保存在本机，'
                '如需迁移到其他设备请使用「导出 / 导入 JSON」。'),"""),
  ("? '暂无本地备份'", "? L.t('暂无本地备份')"),
  (": '最近备份：${Formatter.setDate(sc.backupAt.value!.millisecondsSinceEpoch ~/ 1000)}',",
   ": L.pick('最近备份：${Formatter.setDate(sc.backupAt.value!.millisecondsSinceEpoch ~/ 1000)}', 'Last backup: ${Formatter.setDate(sc.backupAt.value!.millisecondsSinceEpoch ~/ 1000)}'),"),
  ("""                          ? '备份位置：应用私有目录（未指定文件夹时的默认位置）'
                          : '备份文件夹：${sc.backupDir.value}'
                              '（写入失败会自动改存应用私有目录）',""",
   """                          ? L.t('备份位置：应用私有目录（未指定文件夹时的默认位置）')
                          : '${L.pick('备份文件夹：', 'Backup folder: ')}${sc.backupDir.value}'
                              L.t('（写入失败会自动改存应用私有目录）'),"""),
  ("label: Text('选择', style: TextStyle(fontSize: af(context, 11))),",
   "label: Text(L.t('选择'), style: TextStyle(fontSize: af(context, 11))),"),
  ("""                '备份文件已加密（AES-256-GCM，密钥由本机 Keystore 托管），'
                '因此只能在本机恢复；换设备请用「导出 / 导入 JSON」。',""",
   """                L.t('备份文件已加密（AES-256-GCM，密钥由本机 Keystore 托管），'
                '因此只能在本机恢复；换设备请用「导出 / 导入 JSON」。'),"""),
  ("Text('尚未配置服务器',", "Text(L.t('尚未配置服务器'),"),
  ("label: Text(_busy ? S.fieldUpdating : '保存备份到本机',",
   "label: Text(_busy ? S.fieldUpdating : L.t('保存备份到本机'),"),
  ("""                                '（${sc.servers.length} 个服务器）\\n'""",
   """                                L.pick('（${sc.servers.length} 个服务器）\\n', '(${sc.servers.length} servers)\\n')"""),
  ("label: Text('导出备份副本到…',", "label: Text(L.t('导出备份副本到…'),"),
  ("label: Text('从本机备份恢复',", "label: Text(L.t('从本机备份恢复'),"),
  ("? '${S.bkRestoreFail}未发现新的服务器'",
   "? '${S.bkRestoreFail}${L.pick('未发现新的服务器', 'no new servers found')}'"),
  ("label: Text('导出 JSON',", "label: Text(L.t('导出 JSON'),"),
  ("""'导出服务器 JSON 到剪贴板'
                                '（口令加密，含密码）：${sc.servers.length} 台');""",
   """L.pick('导出服务器 JSON 到剪贴板'
                                '（口令加密，含密码）：${sc.servers.length} 台',
                                'Server JSON exported to clipboard (passphrase-encrypted, with passwords): ${sc.servers.length} servers');"""),
  ("label: Text('导入 JSON',", "label: Text(L.t('导入 JSON'),"),
  ("title: Text('导入服务器配置', style: TextStyle(fontSize: af(context, 14))),",
   "title: Text(L.t('导入服务器配置'), style: TextStyle(fontSize: af(context, 14))),"),
  ("label: Text('从剪贴板粘贴',", "label: Text(L.t('从剪贴板粘贴'),"),
  ("child: const Text('导入'),", "child: Text(L.t('导入')),"),
])

sub('lib/pages/torrent_info_files_page.dart', [
  ("child: Text('暂无文件', style: TextStyle(fontSize: af(context, 12))),",
   "child: Text(L.t('暂无文件'), style: TextStyle(fontSize: af(context, 12))),"),
  ("text: '$count 个文件',",
   "text: L.pick('$count 个文件', '$count files'),"),
  ("text: ' · ${Formatter.setSize(total)} · 已完成 ',",
   "text: ' · ${Formatter.setSize(total)} · ${L.t('已完成')} ',"),
  ("'排序',", "L.t('排序'),"),
  ("return '默认';", "return L.t('默认');"),
  ("return '按大小';", "return L.t('按大小');"),
  ("return '按进度';", "return L.t('按进度');"),
  ("label: Text('取消选择',", "label: Text(L.t('取消选择'),"),
  ("""AppLog.instance.op('设置文件优先级：${p.label} ｜ ${ids.length} 个文件'
          '（${t.name} · ${s.name}）',""",
   """AppLog.instance.op(
          '${L.pick('设置文件优先级：${p.label} ｜ ${ids.length} 个文件', 'File priority set: ${p.label} | ${ids.length} files')}（${t.name} · ${s.name}）',"""),
  ("return '跳过';", "return L.t('跳过');"),
  ("return '高';", "return L.t('高');"),
  ("return '最高';", "return L.t('最高');"),
  ("if (f['wanted'] == false) return '跳过';", "if (f['wanted'] == false) return L.t('跳过');"),
  ("return '低';", "return L.t('低');"),
  ("""    switch (badge) {
      case '跳过':
        return cs.outline;
      case '高':
      case '最高':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;""",
   """    if (badge == L.t('跳过')) return cs.outline;
    if (badge == L.t('高') || badge == L.t('最高')) return cs.primary;
    return cs.onSurfaceVariant;"""),
  ("UiDialogs.showToast('当前服务器版本不支持文件重命名', isError: true);",
   "UiDialogs.showToast(L.t('当前服务器版本不支持文件重命名'), isError: true);"),
  ("n.isFile ? '重命名文件' : '重命名文件夹',",
   "n.isFile ? L.t('重命名文件') : L.t('重命名文件夹'),"),
  ("labelText: '新名称',", "labelText: L.t('新名称'),"),
  ("if (mounted) UiDialogs.showToast('已重命名');",
   "if (mounted) UiDialogs.showToast(L.t('已重命名'));"),
  ("child: Text('重命名', style: TextStyle(fontSize: af(context, 11))),",
   "child: Text(L.t('重命名'), style: TextStyle(fontSize: af(context, 11))),"),
  ("'副本 $avail',", "L.pick('副本 $avail', '$avail copies'),"),
  ("'${n.children.length} 项',", "L.pick('${n.children.length} 项', '${n.children.length} items'),"),
])

sub('lib/pages/torrent_add_page.dart', [
  ("if (e.value != '未标记' && !tags.contains(e.value)) tags.add(e.value);",
   "if (e.value != L.t('未标记') && !tags.contains(e.value)) tags.add(e.value);"),
  ("UiDialogs.showToast('${S.tAdded}${r.succeeded.length} 个');",
   "UiDialogs.showToast('${S.tAdded}${L.pick('${r.succeeded.length} 个', '${r.succeeded.length}')}');"),
  ("""          '${_mode == _AddMode.url ? '添加种子（链接' : '添加种子（文件'} ${r.succeeded.length} 条）：'
          '${r.succeeded.map(shortLabel).join(' / ')}',""",
   """          '${_mode == _AddMode.url ? L.pick('添加种子（链接', 'Torrents added (URL'): L.pick('添加种子（文件', 'Torrents added (file')} ${L.pick('${r.succeeded.length} 条', '${r.succeeded.length}')}）：'
          '${r.succeeded.map(shortLabel).join(' / ')}',"""),
  ("""      '${S.tAddBatchPartial}：${S.tAdded}${r.succeeded.length} 个，'
      '${S.tAddFailed} ${r.failed.length} 个',""",
   """      '${S.tAddBatchPartial}：${S.tAdded}${L.pick('${r.succeeded.length} 个', '${r.succeeded.length}')}，'
      '${S.tAddFailed} ${L.pick('${r.failed.length} 个', '${r.failed.length}')}',"""),
  ("""    AppLog.instance.op('添加种子部分失败：成功 ${r.succeeded.length} 条，'
        '失败 ${r.failed.length} 条 —— '""",
   """    AppLog.instance.op(
        '${L.pick('添加种子部分失败：成功 ${r.succeeded.length} 条，失败 ${r.failed.length} 条 —— ', 'Partial add failure: ${r.succeeded.length} ok, ${r.failed.length} failed — ')}'
        ''"""),
  ("title: Text('添加种子', style: TextStyle(fontSize: af(context, 15))),",
   "title: Text(L.t('添加种子'), style: TextStyle(fontSize: af(context, 15))),"),
  ("label: Text('种子链接', style: TextStyle(fontSize: af(context, 11))),",
   "label: Text(L.t('种子链接'), style: TextStyle(fontSize: af(context, 11))),"),
  ("label: Text('种子文件', style: TextStyle(fontSize: af(context, 11))),",
   "label: Text(L.t('种子文件'), style: TextStyle(fontSize: af(context, 11))),"),
  ("title: '目标',", "title: L.t('目标'),"),
  ("label: isQb ? '保存路径（可选）' : '下载目录（可选）',",
   "label: isQb ? L.t('保存路径（可选）') : L.t('下载目录（可选）'),"),
  ("labelText: isQb ? '分类（可选）' : S.addLabelOptional,",
   "labelText: isQb ? L.t('分类（可选）') : S.addLabelOptional,"),
  ("title: '来源',\n      tail: count > 0 ? '已识别 $count 条' : null,",
   "title: L.t('来源'),\n      tail: count > 0 ? L.pick('已识别 $count 条', '$count recognized') : null,"),
  ("labelText: '磁力链接 / 种子链接',", "labelText: L.t('磁力链接 / 种子链接'),"),
  ("title: '来源',\n      tail: _files.isEmpty ? null : '已选 ${_files.length} 个',",
   "title: L.t('来源'),\n      tail: _files.isEmpty ? null : L.pick('已选 ${_files.length} 个', '${_files.length} selected'),"),
  ("Text('清空', style: TextStyle(fontSize: af(context, 11))),",
   "Text(L.t('清空'), style: TextStyle(fontSize: af(context, 11))),"),
  ("'点击选择 .torrent 文件',", "L.t('点击选择 .torrent 文件'),"),
  ("'支持一次多选，自动去重',", "L.t('支持一次多选，自动去重'),"),
  ("_busy ? '${S.fieldUpdating} $_done/$_total' : '添加',",
   "_busy ? '${S.fieldUpdating} $_done/$_total' : L.t('添加'),"),
])

sub('lib/pages/server_dialog.dart', [
  ("Text('原因：$reason', style: TextStyle(fontSize: af(context, 12))),",
   "Text(L.pick('原因：$reason', 'Reason: $reason'), style: TextStyle(fontSize: af(context, 12))),"),
  ("SelectableText('地址：$address',", "SelectableText(L.pick('地址：$address', 'Address: $address'),"),
  ("title: Text('详情', style: TextStyle(fontSize: af(context, 12))),",
   "title: Text(L.t('详情'), style: TextStyle(fontSize: af(context, 12))),"),
  ("isQb ? 'WebUI 接口' : 'RPC 接口',", "isQb ? L.t('WebUI 接口') : L.t('RPC 接口'),"),
  ("""        AppLog.instance.op('取消${_isEdit ? '编辑' : '添加'}服务器（未保存）：'
            '${_draftSummary()}');""",
   """        AppLog.instance.op(
            '${L.pick('取消${_isEdit ? '编辑' : '添加'}服务器（未保存）：', 'Cancelled ${_isEdit ? 'editing' : 'adding'} server (unsaved): ')}'
            '${_draftSummary()}');"""),
  ("labelText: '名称',", "labelText: L.t('名称'),"),
  ("title: '公网连接',", "title: L.t('公网连接'),"),
  ("labelText: '公网地址',", "labelText: L.t('公网地址'),"),
  ("labelText: '端口',", "labelText: L.t('端口'),"),
  ("labelText: '局域网地址',", "labelText: L.t('局域网地址'),"),
  ("hintText: '可选，留空则用公网地址',", "hintText: L.t('可选，留空则用公网地址'),"),
  ("hintText: '可选',", "hintText: L.t('可选'),"),
  ("title: '认证',", "title: L.t('认证'),"),
  ("labelText: '账号',", "labelText: L.t('账号'),"),
  ("labelText: '密码',", "labelText: L.t('密码'),"),
  ("Text('正在连接服务器…', style: TextStyle(fontSize: af(context, 11))),",
   "Text(L.t('正在连接服务器…'), style: TextStyle(fontSize: af(context, 11))),"),
  ("""          '添加服务器失败：缺少账号密码（${_isEdit ? '编辑' : '新增'}，'
          '地址 ${_host.text.trim().isEmpty ? '未填' : _host.text.trim()}）',""",
   """          '${L.pick('添加服务器失败：缺少账号密码（${_isEdit ? '编辑' : '新增'}，地址 ${_host.text.trim().isEmpty ? '未填' : _host.text.trim()}）', 'Add server failed: missing credentials (${_isEdit ? 'edit' : 'add'}, address ${_host.text.trim().isEmpty ? 'empty' : _host.text.trim()})')}"""
   """
          ),"""),
  ("(error == null ? '服务器未按预期响应' : NetError.describe(error)),",
   "(error == null ? L.t('服务器未按预期响应') : NetError.describe(error)),"),
])

sub('lib/pages/log_qb_page.dart', [
  ("_error = '${S.logQbFetchFailed}登录失败，请检查账号与密码';",
   "_error = '${S.logQbFetchFailed}${L.t('登录失败，请检查账号与密码')}';"),
  ("('Transmission 版本', version.isEmpty ? '—' : version),",
   "(L.t('Transmission 版本'), version.isEmpty ? '—' : version),"),
  ("('RPC 版本', Formatter.getString(session, 'rpc-version', def: '—')),",
   "(L.t('RPC 版本'), Formatter.getString(session, 'rpc-version', def: '—')),"),
  ("('种子总数', '${Formatter.getInt(stats, 'torrentCount')}'),",
   "(L.t('种子总数'), '${Formatter.getInt(stats, 'torrentCount')}'),"),
  ("('活动种子', '${Formatter.getInt(stats, 'activeTorrentCount')}'),",
   "(L.t('活动种子'), '${Formatter.getInt(stats, 'activeTorrentCount')}'),"),
  ("('当前下行', Formatter.setSpeed(Formatter.getInt(stats, 'downloadSpeed'))),",
   "(L.t('当前下行'), Formatter.setSpeed(Formatter.getInt(stats, 'downloadSpeed'))),"),
  ("('当前上行', Formatter.setSpeed(Formatter.getInt(stats, 'uploadSpeed'))),",
   "(L.t('当前上行'), Formatter.setSpeed(Formatter.getInt(stats, 'uploadSpeed'))),"),
  ("('累计下载', Formatter.setSize(Formatter.getInt(cum, 'downloadedBytes'))),",
   "(L.t('累计下载'), Formatter.setSize(Formatter.getInt(cum, 'downloadedBytes'))),"),
  ("('累计上传', Formatter.setSize(Formatter.getInt(cum, 'uploadedBytes'))),",
   "(L.t('累计上传'), Formatter.setSize(Formatter.getInt(cum, 'uploadedBytes'))),"),
  ("'下载目录',", "L.t('下载目录'),"),
  ("title: Text('服务器日志',", "title: Text(L.t('服务器日志'),"),
  ("tooltip: '隐私模式（隐藏域名 / IP / 端口）',",
   "tooltip: L.t('隐私模式（隐藏域名 / IP / 端口）'),"),
  ("labelText: '服务器',", "labelText: L.t('服务器'),"),
  ("""                  'Transmission 的 RPC 不提供服务器日志接口（服务端日志只能去读 '
                  'daemon 的日志文件）。这里显示的是它当前能查到的会话诊断信息，'
                  '每 10 秒随页面刷新。',""",
   """                  L.t('Transmission 的 RPC 不提供服务器日志接口（服务端日志只能去读 '
                  'daemon 的日志文件）。这里显示的是它当前能查到的会话诊断信息，'
                  '每 10 秒随页面刷新。'),"""),
])

sub('lib/pages/log_page.dart', [
  ("child: Text('复制全文', style: TextStyle(fontSize: af(context, 13))),",
   "child: Text(L.t('复制全文'), style: TextStyle(fontSize: af(context, 13))),"),
  ("log.op('清空应用日志');", "log.op(L.t('清空应用日志'));"),
  ("title: Text('日志', style: TextStyle(fontSize: af(context, 15))),",
   "title: Text(L.t('日志'), style: TextStyle(fontSize: af(context, 15))),"),
  ("tooltip: '隐私模式（隐藏域名 / IP / 端口）',",
   "tooltip: L.t('隐私模式（隐藏域名 / IP / 端口）'),"),
  ("title: Text('服务器日志', style: TextStyle(fontSize: af(context, 12))),",
   "title: Text(L.t('服务器日志'), style: TextStyle(fontSize: af(context, 12))),"),
  ("? '选择一台服务器后查看它的服务器日志'",
   "? L.t('选择一台服务器后查看它的服务器日志')"),
  ("? 'Transmission 会话诊断（RPC 不提供日志接口）'",
   "? L.t('Transmission 会话诊断（RPC 不提供日志接口）')"),
  ("Text('应用日志', style: TextStyle(fontSize: af(context, 11))),",
   "Text(L.t('应用日志'), style: TextStyle(fontSize: af(context, 11))),"),
  ("""                        '暂无日志记录。应用内的操作提示、网络请求与异常'
                        '会自动记在这里（服务器日志见上方入口）。',""",
   """                        L.t('暂无日志记录。应用内的操作提示、网络请求与异常'
                        '会自动记在这里（服务器日志见上方入口）。'),"""),
])

sub('lib/pages/server_list_page.dart', [
  ("title: Obx(() => Text('服务器（${ctrl.servers.length}）')),",
   "title: Obx(() => Text(L.pick('服务器（${ctrl.servers.length}）', 'Servers (${ctrl.servers.length})'))),"),
  ("tooltip: serverCardsCollapsed.value ? '展开卡片' : '折叠卡片',",
   "tooltip: serverCardsCollapsed.value ? L.t('展开卡片') : L.t('折叠卡片'),"),
  ("AppLog.instance.act('服务器列表', 'AppBar[刷新全部]');",
   "AppLog.instance.act('服务器列表', L.t('AppBar[刷新全部]'));"),
  ("""AppLog.instance.act('服务器列表',
      'AppBar[日志-${v == Routes.log ? '系统日志' : '服务器日志'}]');""",
   """AppLog.instance.act('服务器列表',
      '${L.t('AppBar[日志-')}${v == Routes.log ? L.t('系统日志') : L.t('服务器日志')}${L.t(']')}');"""),
  ("Text('暂无服务器', style: TextStyle(fontSize: af(context, 12))),",
   "Text(L.t('暂无服务器'), style: TextStyle(fontSize: af(context, 12))),"),
  ("'点击 + 添加；无需登录',", "L.t('点击 + 添加；无需登录'),"),
  ("AppLog.instance.act('服务器列表', '悬浮按钮[添加服务器]');",
   "AppLog.instance.act('服务器列表', L.t('悬浮按钮[添加服务器]'));"),
  ("AppLog.instance.act('服务器列表', '左滑[编辑]', target: raw.name);",
   "AppLog.instance.act('服务器列表', L.t('左滑[编辑]'), target: raw.name);"),
  ("AppLog.instance.act('服务器列表', '左滑[删除]·取消', target: raw.name);",
   "AppLog.instance.act('服务器列表', L.t('左滑[删除]·取消'), target: raw.name);"),
  ("AppLog.instance.act('服务器列表', '左滑[删除]', target: raw.name);",
   "AppLog.instance.act('服务器列表', L.t('左滑[删除]'), target: raw.name);"),
  ("AppLog.instance.act('服务器列表', '卡片[进入种子列表]', target: raw.name);",
   "AppLog.instance.act('服务器列表', L.t('卡片[进入种子列表]'), target: raw.name);"),
  ("width: _chipWidth('刷新中', lead: 13),", "width: _chipWidth(L.t('刷新中'), lead: 13),"),
  ("""AppLog.instance.act('服务器列表',
      '卡片[重试]',""",
   """AppLog.instance.act('服务器列表',
      L.t('卡片[重试]'),"""),
  ("""AppLog.instance.act('服务器列表', '卡片[隐私]',""",
   """AppLog.instance.act('服务器列表', L.t('卡片[隐私]'),"""),
  ("detail: allHidden ? '显示地址与端口' : '隐藏地址与端口');",
   "detail: allHidden ? L.t('显示地址与端口') : L.t('隐藏地址与端口');"),
  ("Text('刷新中', style: TextStyle(fontSize: af(context, 9), color: cs.primary)),",
   "Text(L.t('刷新中'), style: TextStyle(fontSize: af(context, 9), color: cs.primary)),"),
  ("""    const List<String> prefixed = <String>[
      '刷新失败：',
      '登录失败：',
      '连接失败：',
    ];""",
   """    final List<String> prefixed = <String>[
      L.t('刷新失败：'),
      L.t('登录失败：'),
      L.t('连接失败：'),
      'Refresh failed: ',
      'Sign-in failed: ',
      'Connection failed: ',
    ];"""),
  ("return '刷新失败：$error';",
   "return '${L.pick('刷新失败：', 'Refresh failed: ')}$error';"),
])

sub('lib/pages/torrent_list_page.dart', [
  ("tooltip: _cardsCollapsed ? '展开卡片' : '折叠卡片',",
   "tooltip: _cardsCollapsed ? L.t('展开卡片') : L.t('折叠卡片'),"),
  ("tooltip: '站点打码',", "tooltip: L.t('站点打码'),"),
  ("why != null && why.startsWith('登录失败');",
   "why != null &&\n        (why.startsWith(L.t('登录失败')) || why.startsWith('Sign-in failed'));"),
  ("label: Text('清除', style: TextStyle(fontSize: af(context, 11))),",
   "label: Text(L.t('清除'), style: TextStyle(fontSize: af(context, 11))),"),
  ("AppLog.instance.act('种子列表', '筛选[清除]');",
   "AppLog.instance.act('种子列表', L.t('筛选[清除]'));"),
  ("onTap: () => _runSelected(ctrl.resumeSelected, '开始'),",
   "onTap: () => _runSelected(ctrl.resumeSelected, L.t('开始')),"),
  ("onTap: () => _runSelected(ctrl.pauseSelected, '暂停'),",
   "onTap: () => _runSelected(ctrl.pauseSelected, L.t('暂停')),"),
  ("onTap: () => _runSelected(ctrl.recheckSelected, '重新校验'),",
   "onTap: () => _runSelected(ctrl.recheckSelected, L.t('重新校验')),"),
  ("AppLog.instance.act('种子列表', '多选栏[批量编辑]', target: '${hashes.length} 个');",
   "AppLog.instance.act('种子列表', L.t('多选栏[批量编辑]'), target: '${hashes.length} 个');"),
  ("AppLog.instance.act('种子列表', '多选栏[复制哈希]', target: '${hashes.length} 个');",
   "AppLog.instance.act('种子列表', L.t('多选栏[复制哈希]'), target: '${hashes.length} 个');"),
  ("AppLog.instance.act('种子列表', '多选栏[复制磁力链]', target: '${magnets.length} 个');",
   "AppLog.instance.act('种子列表', L.t('多选栏[复制磁力链]'), target: '${magnets.length} 个');"),
  ("AppLog.instance.act('种子列表', '多选栏[批量导出]', target: '${list.length} 个');",
   "AppLog.instance.act('种子列表', L.t('多选栏[批量导出]'), target: '${list.length} 个');"),
  ("_runSelected(() => ctrl.queueMoveSelected(v), '队列移动:$v'),",
   "_runSelected(() => ctrl.queueMoveSelected(v), L.pick('队列移动:$v', 'Queue move:$v')),"),
])
