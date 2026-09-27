# -*- coding: utf-8 -*-
"""列出所有带插值 $ 的裸中文串（需要参数化函数）与纯文案串（可就地 L.t）。"""
import os, re, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

SINGLE = re.compile(r"'((?:[^'\\]|\\.)*)'")
ZH = re.compile(r'[\u4e00-\u9fff]')
SKIP = {'lib/utils/i18n_en.dart', 'lib/utils/strings.dart'}

interp, plain = {}, {}
for root, dirs, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(root, fn).replace(os.sep, '/')
        if p in SKIP:
            continue
        src = io.open(p, encoding='utf-8').read()
        for i, line in enumerate(src.splitlines(), 1):
            st = line.strip()
            if st.startswith('//'):
                continue
            for m in SINGLE.finditer(line):
                s = m.group(1)
                if not ZH.search(s):
                    continue
                pre = line[:m.start()]
                if '//' in pre and m.start() > pre.index('//'):
                    continue
                if 'L.t(' in line or 'L.pick(' in line:
                    continue
                if ('AppLog' in line or '.op(' in line or '.net(' in line
                        or '.act(' in line or '.ui(' in line or '_log(' in line
                        or '.info(' in line or '.error(' in line or '.warn(' in line):
                    continue
                has_interp = bool(re.search(r'\$\{|\$[a-zA-Z]', s))
                tgt = interp if has_interp else plain
                tgt.setdefault(p, []).append(s)
                break

print('===== 带插值（需参数化函数）=====')
n = 0
for p in sorted(interp):
    print('--', p)
    for s in interp[p]:
        print('   %r' % s)
        n += 1
print('插值合计:', n)
print()
print('===== 纯文案（可就地 L.t）=====')
m2 = 0
for p in sorted(plain):
    print('--', p, len(plain[p]))
    m2 += len(plain[p])
print('纯文案合计:', m2)
