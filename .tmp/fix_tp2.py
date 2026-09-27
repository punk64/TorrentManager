# -*- coding: utf-8 -*-
"""trackers 页剩余修复"""
import io

p = 'lib/pages/torrent_info_trackers_page.dart'
src = io.open(p, encoding='utf-8').read()

old1 = (
    "                      '这是私有种子（Private Torrent）\\n'\n"
    "                      '请保持 DHT / PEX / LSD 关闭 —— 它们会绕过 Tracker 广播本种子，'\n"
    "                      '可能导致 passkey 泄露并被站点封禁账号。',"
)
new1 = (
    "                      L.t('这是私有种子（Private Torrent）\\n'\n"
    "                      '请保持 DHT / PEX / LSD 关闭 —— 它们会绕过 Tracker 广播本种子，'\n"
    "                      '可能导致 passkey 泄露并被站点封禁账号。'),"
)
assert old1 in src, 'private warning not found'
src = src.replace(old1, new1)

fixes = [
    (
        "L.pick('修改 Tracker：$original → ${_oneLine(result)}', 'Tracker edited: $original → ${_oneLine(result)}')\n              '（${t.name} · ${s.name}）',",
        "'${L.pick('修改 Tracker：$original → ${_oneLine(result)}', 'Tracker edited: $original → ${_oneLine(result)}')}（${t.name} · ${s.name}）',",
    ),
    (
        "L.pick('添加 Tracker：${_oneLine(result)}', 'Tracker added: ${_oneLine(result)}')\n              '（${t.name} · ${s.name}）',",
        "'${L.pick('添加 Tracker：${_oneLine(result)}', 'Tracker added: ${_oneLine(result)}')}（${t.name} · ${s.name}）',",
    ),
    (
        "L.pick('修改 Tracker：$original → ${_oneLine(urls.first)}', 'Tracker edited: $original → ${_oneLine(urls.first)}')\n              '（${t.name} · ${s.name}）',",
        "'${L.pick('修改 Tracker：$original → ${_oneLine(urls.first)}', 'Tracker edited: $original → ${_oneLine(urls.first)}')}（${t.name} · ${s.name}）',",
    ),
    (
        "L.pick('Tracker 操作失败（${editing ? '修改' : '添加'}）：', 'Tracker operation failed (${editing ? 'edit' : 'add'}): ')",
        "'${L.pick('Tracker 操作失败（${editing ? '修改' : '添加'}）：', 'Tracker operation failed (${editing ? 'edit' : 'add'}): ')}",
    ),
    (
        "L.pick('删除 Tracker：$url（${t.name} · ${s.name}）', 'Tracker removed: $url (${t.name} · ${s.name})'),",
        "'${L.pick('删除 Tracker：$url（${t.name} · ${s.name}）', 'Tracker removed: $url (${t.name} · ${s.name})')}',",
    ),
    (
        "L.pick('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}', 'Failed to remove tracker $url · ${Formatter.safeErr(e)}'),",
        "'${L.pick('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}', 'Failed to remove tracker $url · ${Formatter.safeErr(e)}')}',",
    ),
]
for old, new in fixes:
    if old in src:
        src = src.replace(old, new)
        print('fixed:', old[:50].replace('\n', '|'))
    else:
        print('SKIP (not found):', old[:50].replace('\n', '|'))

io.open(p, 'w', encoding='utf-8').write(src)
print('done')
