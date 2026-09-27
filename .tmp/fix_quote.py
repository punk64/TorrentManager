# -*- coding: utf-8 -*-
import io
p = 'lib/utils/strings.dart'
src = io.open(p, encoding='utf-8').read()
bad = "'Could not load this server's settings;"
good = "'Could not load this server\\'s settings;"
assert bad in src, 'pattern not found'
src = src.replace(bad, good)
io.open(p, 'w', encoding='utf-8').write(src)
print('fixed')
