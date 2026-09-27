# -*- coding: utf-8 -*-
"""导出指定文件的中文行（带行号与原文）"""
import io, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ZH = re.compile(r'[\u4e00-\u9fff]')
SINGLE = re.compile(r"'((?:[^'\\]|\\.)*)'")
p = sys.argv[1]
src = io.open(p, encoding='utf-8').read().splitlines()
for i, line in enumerate(src, 1):
    st = line.strip()
    if st.startswith('//'):
        continue
    for m in SINGLE.finditer(line):
        s = m.group(1)
        if ZH.search(s):
            pre = line[:m.start()]
            if '//' in pre and m.start() > pre.index('//'):
                continue
            if 'L.t(' in line or 'L.pick(' in line:
                continue
            print('%5d| %s' % (i, st[:150]))
            break
