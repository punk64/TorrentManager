# -*- coding: utf-8 -*-
"""torrent_controller.dart 国际化批量替换"""
import io

p = 'lib/controllers/torrent_controller.dart'
src = io.open(p, encoding='utf-8').read()
pairs = [
  ("return '种子大小';", "return L.t('种子大小');"),
  ("return '分享比率';", "return L.t('分享比率');"),
  ("return '做种人数';", "return L.t('做种人数');"),
  ("return '下载速度';", "return L.t('下载速度');"),
  ("return '上传速度';", "return L.t('上传速度');"),
  ("return '下载总量';", "return L.t('下载总量');"),
  ("return '上传总量';", "return L.t('上传总量');"),
  ("return '添加时间';", "return L.t('添加时间');"),
  ("return '完成时间';", "return L.t('完成时间');"),
  ("return '做种时长';", "return L.t('做种时长');"),
  ("return '种子名称';", "return L.t('种子名称');"),
  ("return '种子进度';", "return L.t('种子进度');"),
  ("return '种子状态';", "return L.t('种子状态');"),
  ("return '分类';", "return L.t('分类');"),
  ("return '标签';", "return L.t('标签');"),
  ("return '路径';", "return L.t('路径');"),
  ("return '站点';", "return L.t('站点');"),
  ("return t.tagList.isEmpty ? const <String>['未标记'] : t.tagList;",
   "return t.tagList.isEmpty ? <String>[L.t('未标记')] : t.tagList;"),
  ("return <String>[t.site.isEmpty ? '未知站点' : t.site];",
   "return <String>[t.site.isEmpty ? L.t('未知站点') : t.site];"),
  ("if (v.isNotEmpty && v != '未指定') out[v] = e.count;",
   "if (v.isNotEmpty && v != L.t('未指定')) out[v] = e.count;"),
  ("""    AppLog.instance.view(
      '种子列表页 ${v ? '进入前台 → 恢复自动取数' : '退到后台 → 停止自动取数'}',
      key: '列表:visible',
    );""",
   """    AppLog.instance.view(
      LogT.listVisible(v),
      key: '列表:visible',
    );"""),
  ("""      AppLog.instance.op(
          '创建分类「$n」${p == null ? '' : ' → $p'}：${NetError.describe(e)}',
          level: 'WARN',
          scope: s.logScope);""",
   """      AppLog.instance.op(
          LogT.catCreateFail(n, p ?? '', NetError.describe(e)),
          level: 'WARN',
          scope: s.logScope);"""),
  ("""'种子列表[${s.name}] 先用缓存渲染 ${cached.length} 条（真实数据随后覆盖）',""",
   "LogT.listCacheRender(s.name, cached.length),"),
  ("'种子列表[${s.name}] 开始加载（全量）',", "LogT.listStart(s.name),"),
  ("AppLog.instance.net('列表请求 403，已重新登录并重试',",
   "AppLog.instance.net(L.t('列表请求 403，已重新登录并重试'),"),
  ("final String why = r.reason ?? '登录失败';",
   "final String why = r.reason ?? S.loginFailed;"),
  ("""'自动取数被跳过：列表正在滚动（防抖中）',""",
   "L.t('自动取数被跳过：列表正在滚动（防抖中）'),"),
  (""".error('增量合并失败（$hash）：${NetError.describe(e)}');""",
   ".error(LogT.mergeFail(hash, NetError.describe(e)));"),
  ("""'TR 种子解析失败（${m['hashString']}）：${NetError.describe(e)}',""",
   "LogT.trParseFail(m['hashString']?.toString() ?? '', NetError.describe(e)),"),
  ("AppLog.instance.act('种子列表', '筛选[${f.label}]');",
   "AppLog.instance.act('种子列表', LogT.filterApplied(f.label));"),
  ("AppLog.instance.act('种子列表', '细分筛选[${subStateLabel(v)}]');",
   "AppLog.instance.act('种子列表', LogT.subFilterApplied(subStateLabel(v)));"),
  ("AppLog.instance.op('排序：${key.name} · ${sortDesc.value ? '降序' : '升序'}');",
   "AppLog.instance.op(LogT.sortChanged(key.name, sortDesc.value));"),
  ("AppLog.instance.op('排序方向：${desc ? '降序' : '升序'}');",
   "AppLog.instance.op(LogT.sortDirChanged(desc));"),
  ("AppLog.instance.op('站点打码：${v ? '开启' : '关闭'}');",
   "AppLog.instance.op(LogT.siteMaskChanged(v));"),
  ("""  throw StateError('选中的种子里没有可用的 Transmission 任务 ID'
      '（共选中 ${selected.length} 个，都没有 trId）');""",
   "throw StateError(S.trNoTaskSelected(selected.length));"),
  ("""  throw StateError('没有可删除的 Transmission 任务 ID'
      '（${b.items.length} 个种子都缺少 trId）');""",
   "throw StateError(S.trNothingDeletable(b.items.length));"),
  ("'所选 ${hashes.length} 个种子都没有可用的 Transmission 任务 ID');",
   "S.trNoneUsable(hashes.length));"),
  ("throw StateError('该种子缺少 Transmission 任务 ID，无法重命名');",
   "throw StateError(S.trNoTaskRename);"),
]
n = 0
for old, new in pairs:
    if old in src:
        src = src.replace(old, new); n += 1
    else:
        print('MISS tc: %r' % old[:76].replace('\n', '\\n'))
if "import '../utils/i18n.dart';" not in src:
    src = src.replace("import '../utils/app_log.dart';",
                      "import '../utils/app_log.dart';\nimport '../utils/i18n.dart';\nimport '../utils/log_text.dart';", 1)
io.open(p, 'w', encoding='utf-8').write(src)
print('torrent_controller:', n, '/', len(pairs))
