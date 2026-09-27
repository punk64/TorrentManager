# -*- coding: utf-8 -*-
"""server_dialog 修复：去 const + 修 658"""
import io, re

p = 'lib/pages/server_dialog.dart'
src = io.open(p, encoding='utf-8').read()

# 1) 658 结构修复
old = """        AppLog.instance.net(
          '${L.pick('添加服务器失败：缺少账号密码（${_isEdit ? '编辑' : '新增'}，地址 ${_host.text.trim().isEmpty ? '未填' : _host.text.trim()}）', 'Add server failed: missing credentials (${_isEdit ? 'edit' : 'add'}, address ${_host.text.trim().isEmpty ? 'empty' : _host.text.trim()})')}
          ),
        );"""
new = """        AppLog.instance.net(
          L.pick('添加服务器失败：缺少账号密码（${_isEdit ? '编辑' : '新增'}，地址 ${_host.text.trim().isEmpty ? '未填' : _host.text.trim()}）', 'Add server failed: missing credentials (${_isEdit ? 'edit' : 'add'}, address ${_host.text.trim().isEmpty ? 'empty' : _host.text.trim()})'),
        );"""
assert old in src, 'dlg 658 not found'
src = src.replace(old, new)

# 2) 含 L.t 的 const InputDecoration 去 const
lines = src.splitlines(True)
out = []
i = 0
removed = 0
while i < len(lines):
    line = lines[i]
    if 'const InputDecoration(' in line:
        # 向后找 4 行内是否有 L.t
        window = ''.join(lines[i:i+5])
        if 'L.t(' in window:
            out.append(line.replace('const InputDecoration(', 'InputDecoration('))
            removed += 1
            i += 1
            continue
    out.append(line)
    i += 1
src = ''.join(out)
io.open(p, 'w', encoding='utf-8').write(src)
print('const removed:', removed)

# 3) 其他文件的 MISS 补刀
# share_page 导出 JSON 日志（跨行）
p = 'lib/pages/share_page.dart'
src = io.open(p, encoding='utf-8').read()
old = """'导出服务器 JSON 到剪贴板'
                                '（口令加密，含密码）：${sc.servers.length} 台');"""
new = """L.pick('导出服务器 JSON 到剪贴板'
                                '（口令加密，含密码）：${sc.servers.length} 台',
                                'Server JSON exported to clipboard (passphrase-encrypted, with passwords): ${sc.servers.length} servers');"""
if old in src:
    src = src.replace(old, new)
    print('share fixed')
else:
    print('share MISS')
io.open(p, 'w', encoding='utf-8').write(src)

# files_page wanted 跳过
p = 'lib/pages/torrent_info_files_page.dart'
src = io.open(p, encoding='utf-8').read()
old = "if (f['wanted'] == false) return '跳过';"
if old in src:
    src = src.replace(old, "if (f['wanted'] == false) return L.t('跳过');")
    print('files fixed')
else:
    # 可能已被上一条 'return 跳过' 全局替换
    print('files already ok:', "L.t('跳过')" in src)
io.open(p, 'w', encoding='utf-8').write(src)

# server_list 两处 act
p = 'lib/pages/server_list_page.dart'
src = io.open(p, encoding='utf-8').read()
old1 = """AppLog.instance.act('服务器列表',
      'AppBar[日志-${v == Routes.log ? '系统日志' : '服务器日志'}]');"""
if old1 in src:
    src = src.replace(old1, """AppLog.instance.act('服务器列表',
      '${L.t('AppBar[日志-')}${v == Routes.log ? L.t('系统日志') : L.t('服务器日志')}${L.t(']')}');""")
    print('sl act1 fixed')
old2 = """AppLog.instance.act('服务器列表',
      '卡片[重试]',"""
if old2 in src:
    src = src.replace(old2, """AppLog.instance.act('服务器列表',
      L.t('卡片[重试]'),""")
    print('sl act2 fixed')
io.open(p, 'w', encoding='utf-8').write(src)
print('done')
