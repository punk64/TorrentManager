# -*- coding: utf-8 -*-
"""导出全部缺失 en_map 的 L.t key（处理相邻拼接：合并 L.t( 后跨行的字符串段）"""
import os, re, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

LT = re.compile(r"L\.t\(\s*'((?:[^'\\]|\\.)*)'")
ENPAIR = re.compile(r"'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'")
en = io.open('lib/utils/i18n_en.dart', encoding='utf-8').read()
enkeys = set(m.group(1) for m in ENPAIR.finditer(en))

missing = set()
for root, dirs, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(root, fn).replace(os.sep, '/')
        src = re.sub(r'//[^\n]*', '', io.open(p, encoding='utf-8').read())
        for m in LT.finditer(src):
            k = m.group(1)
            if k not in enkeys:
                missing.add(k)
out = io.open('.tmp/missing_keys.txt', 'w', encoding='utf-8')
for k in sorted(missing):
    out.write(k + '\n')
out.close()
print('missing keys:', len(missing))
