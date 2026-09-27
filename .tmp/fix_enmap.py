# -*- coding: utf-8 -*-
"""重建 en_map_4.txt：把真实换行切断的条目转义合并回去"""
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

p = r'D:\WorkBuddy_Work\AndroidDevelopment\TorrentManager\tools\i18n\en_map_4.txt'
raw = io.open(p, encoding='utf-8').read().split('\n')

entries = []
pending = ''
for line in raw:
    if line == '':
        continue
    if '\t' in line:
        k, v = line.split('\t', 1)
        k = pending + k
        pending = ''
        entries.append((k, v))
    else:
        pending = pending + line + '\\n'

print('rebuilt entries:', len(entries))
seen = set()
out = []
for k, v in entries:
    if k in seen:
        continue
    seen.add(k)
    out.append('%s\t%s' % (k, v))
io.open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('deduped written:', len(out))
