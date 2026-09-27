# -*- coding: utf-8 -*-
"""补齐漏网的短 key"""
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
p = r'D:\WorkBuddy_Work\AndroidDevelopment\TorrentManager\tools\i18n\en_map_4.txt'
M = {
    '不是对象': 'not an object',
    '亮': 'Light',
    '分': 'min',
    '列表': 'List',
    '无 Tracker 时也能通过 DHT 网络找到 Peer；私有种子必须关闭。':
        'Finds peers through the DHT network even without a tracker; must be off for private torrents.',
    ' · 下载中 ': ' · downloading ',
    ' · 对其上传 ': ' · uploading to you ',
    '暂无日志记录。应用内的操作提示、网络请求与异常会自动记在这里（服务器日志见上方入口）。':
        'No log entries yet. In-app toasts, network requests and errors are recorded here automatically (server logs via the entry above).',
    '这是便携备份（口令加密），请用「导入便携备份」并输入口令':
        'This is a portable backup (passphrase-encrypted); use "Import portable backup" and enter the passphrase',
}
exist = set()
for line in io.open(p, encoding='utf-8'):
    line = line.rstrip('\n')
    if line and '\t' in line:
        exist.add(line.split('\t', 1)[0])
n = 0
with io.open(p, 'a', encoding='utf-8') as f:
    for k, v in M.items():
        if k in exist:
            print('skip:', k)
            continue
        f.write('%s\t%s\n' % (k, v))
        n += 1
print('appended:', n)
