# -*- coding: utf-8 -*-
"""controllers 中文行分类标注（LOG 上下文判定）"""
import io, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ZH = re.compile(r'[\u4e00-\u9fff]')
SINGLE = re.compile(r"'((?:[^'\\]|\\.)*)'")
for p in ['lib/controllers/server_controller.dart', 'lib/controllers/torrent_controller.dart',
          'lib/controllers/theme_controller.dart']:
    src = io.open(p, encoding='utf-8').read().splitlines()
    print('=====', p)
    for i, line in enumerate(src, 1):
        st = line.strip()
        if st.startswith('//'):
            continue
        hit = None
        for m in SINGLE.finditer(line):
            s = m.group(1)
            if ZH.search(s):
                pre = line[:m.start()]
                if '//' in pre and m.start() > pre.index('//'):
                    continue
                if 'L.t(' in line or 'L.pick(' in line:
                    continue
                hit = st
                break
        if hit:
            ctx = ''
            for j in range(i-2, max(0, i-6), -1):
                up = src[j].strip()
                if up:
                    ctx = up[:70]
                    break
            tag = 'LOG' if ('AppLog' in ctx or '.op(' in ctx or '.net(' in ctx
                            or '.act(' in ctx or 'level:' in ctx or 'scope:' in ctx) else 'UI '
            print('%s %5d| %s' % (tag, i, hit[:120]))
