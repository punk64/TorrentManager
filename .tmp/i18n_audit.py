# -*- coding: utf-8 -*-
"""全项目 i18n 审计：
1) 收集 lib/ 所有 L.t('...') 运行时调用（含 strings.dart 之外），核对 en_map 覆盖
2) 统计页面/组件层裸中文（字符串字面量含中文，未走 L.t/L.pick/AppLog）
"""
import os, re, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

LT = re.compile(r"L\.t\(\s*'((?:[^'\\]|\\.)*)'")
ENPAIR = re.compile(r"'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'")
SINGLE = re.compile(r"'((?:[^'\\]|\\.)*)'")
ZH = re.compile(r'[\u4e00-\u9fff]')

en = io.open('lib/utils/i18n_en.dart', encoding='utf-8').read()
enkeys = set(m.group(1) for m in ENPAIR.finditer(en))

missing = {}
lt_total = 0
for root, dirs, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(root, fn).replace(os.sep, '/')
        src = io.open(p, encoding='utf-8').read()
        src_nc = re.sub(r'//[^\n]*', '', src)
        for m in LT.finditer(src_nc):
            lt_total += 1
            k = m.group(1)
            if k not in enkeys:
                missing.setdefault(p, []).append(k)

print('== L.t 运行时调用（全 lib，除注释）==', lt_total)
print('== en_map key 数 ==', len(enkeys))
print('== 缺英文映射的 L.t key ==')
n = 0
for p in sorted(missing):
    for k in missing[p]:
        print(' %s | %s' % (p, k))
        n += 1
print('缺失合计:', n)

print()
print('== 裸中文统计（非 L.t/L.pick/AppLog/注释/en_map/strings.dart）==')
raw_total = 0
by_file = {}
for root, dirs, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(root, fn).replace(os.sep, '/')
        if p in ('lib/utils/i18n_en.dart',):
            continue
        src = io.open(p, encoding='utf-8').read()
        cnt = 0
        samples = []
        for i, line in enumerate(src.splitlines(), 1):
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
                    if 'AppLog' in line or '.op(' in line or '.net(' in line or '.act(' in line or '.ui(' in line:
                        continue
                    hit = st
                    break
            if hit:
                cnt += 1
                if len(samples) < 3:
                    samples.append('%d: %s' % (i, hit[:110]))
        if cnt:
            by_file[p] = (cnt, samples)
            raw_total += cnt
for p in sorted(by_file, key=lambda x: -by_file[x][0]):
    cnt, samples = by_file[p]
    print('%4d  %s' % (cnt, p))
    for s in samples:
        print('        ', s)
print('裸中文合计:', raw_total)
