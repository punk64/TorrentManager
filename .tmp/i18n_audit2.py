# -*- coding: utf-8 -*-
"""二级盲区审计：
1) style_keys.dart 里 title:/backgroundLabel:/textLabel:/help: 的常量值（经变量进 L.t）
2) theme.dart 主题 name/descriptor 的显示路径是否过 L.t
3) page_preview.dart 的示例文本是否过 L.t
"""
import re, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

ENPAIR = re.compile(r"'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'")
en = io.open('lib/utils/i18n_en.dart', encoding='utf-8').read()
enkeys = set(m.group(1) for m in ENPAIR.finditer(en))

sk = io.open('lib/app/style_keys.dart', encoding='utf-8').read()
vals = re.findall(r"(?:title|backgroundLabel|textLabel|help):\s*'((?:[^'\\]|\\.)*)'", sk)
uniq = sorted(set(vals))
miss = [v for v in uniq if v not in enkeys]
print('style_keys 常量值:', len(uniq), '唯一 | en_map 未覆盖:', len(miss))
for v in miss:
    print('  MISS |', v)

th = io.open('lib/app/theme.dart', encoding='utf-8').read()
names = sorted(set(re.findall(r"name:\s*'((?:[^'\\]|\\.)*)'", th) + re.findall(r"descriptor:\s*'((?:[^'\\]|\\.)*)'", th)))
miss2 = [v for v in names if v not in enkeys]
print('theme 主题名/描述:', len(names), '唯一 | en_map 未覆盖:', len(miss2))
for v in miss2:
    print('  MISS |', v)

pv = io.open('lib/widgets/page_preview.dart', encoding='utf-8').read()
pvs = sorted(set(re.findall(r"'((?:[^'\\]|\\.)*)'", pv)))
pv_zh = [v for v in pvs if re.search(r'[\u4e00-\u9fff]', v)]
miss3 = [v for v in pv_zh if v not in enkeys]
print('page_preview 中文串:', len(pv_zh), '唯一 | en_map 未覆盖:', len(miss3))
for v in miss3:
    print('  MISS |', v)
