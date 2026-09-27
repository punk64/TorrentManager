# -*- coding: utf-8 -*-
import io
p = 'lib/pages/torrent_info_trackers_page.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
    ("AppLog.instance.op('${L.pick('删除 Tracker：$url（${t.name} · ${s.name}）', 'Tracker removed: $url (${t.name} · ${s.name})')}',",
     "AppLog.instance.op(L.pick('删除 Tracker：$url（${t.name} · ${s.name}）', 'Tracker removed: $url (${t.name} · ${s.name})'),"),
    ("AppLog.instance.error('${L.pick('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}', 'Failed to remove tracker $url · ${Formatter.safeErr(e)}')}',",
     "AppLog.instance.error(L.pick('删除 Tracker 失败：$url · ${Formatter.safeErr(e)}', 'Failed to remove tracker $url · ${Formatter.safeErr(e)}'),"),
]
for old, new in pairs:
    assert old in src, old[:60]
    src = src.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(src)
print('fixed 2')
