# -*- coding: utf-8 -*-
import io

# share_page 修复
p = 'lib/pages/share_page.dart'
src = io.open(p, encoding='utf-8').read()
old1 = """                          : '${L.pick('备份文件夹：', 'Backup folder: ')}${sc.backupDir.value}'
                              L.t('（写入失败会自动改存应用私有目录）'),"""
new1 = """                          : '${L.pick('备份文件夹：', 'Backup folder: ')}${sc.backupDir.value}'
                              '${L.t('（写入失败会自动改存应用私有目录）')}',"""
assert old1 in src, 'share1'
src = src.replace(old1, new1)

old2 = """                                '${S.bkExportOk}'
                                L.pick('（${sc.servers.length} 个服务器）\\n', '(${sc.servers.length} servers)\\n')
                                '${_shortPath(path)}');"""
new2 = """                                '${S.bkExportOk}'
                                '${L.pick('（${sc.servers.length} 个服务器）\\n', '(${sc.servers.length} servers)\\n')}'
                                '${_shortPath(path)}');"""
assert old2 in src, 'share2'
src = src.replace(old2, new2)

old3 = """                                    '导出服务器 JSON 到剪贴板'
                                    '（口令加密，含密码）：${sc.servers.length} 台');"""
new3 = """                                    '${L.pick('导出服务器 JSON 到剪贴板'
                                    '（口令加密，含密码）：${sc.servers.length} 台', 'Server JSON exported to clipboard (passphrase-encrypted, with passwords): ${sc.servers.length} servers')}');"""
assert old3 in src, 'share3'
src = src.replace(old3, new3)
io.open(p, 'w', encoding='utf-8').write(src)
print('share fixed 3')

# server_list 修复缺括号
p = 'lib/pages/server_list_page.dart'
src = io.open(p, encoding='utf-8').read()
old = "detail: allHidden ? L.t('显示地址与端口') : L.t('隐藏地址与端口');"
new = "detail: allHidden ? L.t('显示地址与端口') : L.t('隐藏地址与端口'));"
assert old in src, 'sl'
src = src.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(src)
print('server_list fixed')

# files_page 两个 unused warning：_prioBadgeOf/_prioBadgeColor 无人调用了？
# 原因：switch 改 if 后函数还在但没人用——查调用点再定
