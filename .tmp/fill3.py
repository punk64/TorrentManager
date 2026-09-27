# -*- coding: utf-8 -*-
import io
p = r'D:\WorkBuddy_Work\AndroidDevelopment\TorrentManager\tools\i18n\en_map_4.txt'
exist = set()
for line in io.open(p, encoding='utf-8'):
    if line.strip() and '\t' in line:
        exist.add(line.split('\t', 1)[0])
with io.open(p, 'a', encoding='utf-8') as f:
    if '地址或端口不对，接口未找到（HTTP 404）' not in exist:
        f.write('地址或端口不对，接口未找到（HTTP 404）\tAddress or port is wrong; endpoint not found (HTTP 404)\n')
        print('appended')
    else:
        print('already there')
