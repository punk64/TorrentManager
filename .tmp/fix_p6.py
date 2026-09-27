# -*- coding: utf-8 -*-
"""批6：edit_fields/edit_sheet/log_selection/main/drawer"""
import io

def sub(p, pairs, i18n_path='../utils/i18n.dart'):
    src = io.open(p, encoding='utf-8').read()
    n = 0
    for old, new in pairs:
        if old in src:
            src = src.replace(old, new); n += 1
        else:
            print('MISS %s: %r' % (p.split('/')[-1], old[:76].replace('\n', '\\n')))
    if i18n_path and "import '%s'" % i18n_path not in src:
        if "import '../utils/strings.dart';" in src:
            src = src.replace("import '../utils/strings.dart';",
                              "import '%s';\nimport '../utils/strings.dart';" % i18n_path, 1)
        elif "import '../utils/app_log.dart';" in src:
            src = src.replace("import '../utils/app_log.dart';",
                              "import '../utils/app_log.dart';\nimport '%s';" % i18n_path, 1)
    io.open(p, 'w', encoding='utf-8').write(src)
    print('%s: %d/%d' % (p.split('/')[-1], n, len(pairs)))

sub('lib/widgets/torrent_edit_fields.dart', [
  ("? _badge('新建', cs.primary)", "? _badge(L.t('新建'), cs.primary)"),
  (": _badge(fromServer ? '下载器' : '列表',",
   ": _badge(fromServer ? L.t('下载器') : L.t('列表'),"),
  ("Text('种子 ×$n',", "Text(L.pick('种子 ×$n', 'Torrents ×$n'),"),
  ("label: Text('新建「」',", 'label: Text(L.pick(\'新建「」\', \'Create "$q"\'),'),
])

sub('lib/widgets/torrent_edit_sheet.dart', [
  ("""    AppLog.instance.act(
        '批量编辑', '提交 $_opCount 项 × ${widget.hashes.length} 个种子');""",
   """    AppLog.instance.act(
        L.t('批量编辑'),
        L.pick('提交 $_opCount 项 × ${widget.hashes.length} 个种子',
            'Commit $_opCount items × ${widget.hashes.length} torrents'));"""),
  ("color: _result!.contains('失败 0') ? cs.primary : cs.error,",
   "color: _result!.contains(L.pick('失败 0', '0 failed')) ? cs.primary : cs.error,"),
])

sub('lib/widgets/log_selection.dart', [
  ("UiDialogs.showToast('${S.logExportFailedPrefix}没有可导出的日志', isError: true);",
   "UiDialogs.showToast('${S.logExportFailedPrefix}${L.t('没有可导出的日志')}', isError: true);"),
  ("AppLog.instance.op('导出日志：$name0（$n 条，${masked ? '已打码' : '未打码'}）');",
   "AppLog.instance.op(L.pick('导出日志：$name0（$n 条，${masked ? '已打码' : '未打码'}）', 'Log exported: $name0 ($n rows, ${masked ? 'masked' : 'unmasked'})'));"),
  ("title: Text('导出日志', style: TextStyle(fontSize: af(context, 14))),",
   "title: Text(L.t('导出日志'), style: TextStyle(fontSize: af(context, 14))),"),
  ("'下一步会弹出系统「另存为」，请选择保存位置（如「下载」文件夹）',",
   "L.t('下一步会弹出系统「另存为」，请选择保存位置（如「下载」文件夹）'),"),
])

sub('lib/main.dart', [
  ("""      AppLog.instance.error(
          'UI 异常: ${NetError.describe(details.exceptionAsString())}',
          source: AppLog.srcApp);""",
   """      AppLog.instance.error(
          '${L.pick('UI 异常: ', 'UI error: ')}${NetError.describe(details.exceptionAsString())}',
          source: AppLog.srcApp);"""),
  ("AppLog.instance.error('未捕获异常: ${NetError.describe(error)}');\n      return true;",
   "AppLog.instance.error('${L.pick('未捕获异常: ', 'Uncaught error: ')}${NetError.describe(error)}');\n      return true;"),
  ("AppLog.instance.info('应用启动');", "AppLog.instance.info(L.t('应用启动'));"),
  ("AppLog.instance.error('未捕获异常: ${NetError.describe(error)}');\n    if (kDebugMode) {",
   "AppLog.instance.error('${L.pick('未捕获异常: ', 'Uncaught error: ')}${NetError.describe(error)}');\n    if (kDebugMode) {"),
  ("""                '屏幕诊断: width=${mq.size.width.toStringAsFixed(1)}dp '
                'height=${mq.size.height.toStringAsFixed(1)}dp '
                'dpr=${mq.devicePixelRatio} '
                'textScaler=$sysScale(钳制后$clamped) '
                '设计基准=445dp(Mate 80 Pro)');""",
   """                '${L.pick('屏幕诊断: ', 'Screen diagnostics: ')}'
                'width=${mq.size.width.toStringAsFixed(1)}dp '
                'height=${mq.size.height.toStringAsFixed(1)}dp '
                'dpr=${mq.devicePixelRatio} '
                'textScaler=$sysScale(${L.pick('钳制后', 'clamped')}$clamped) '
                '${L.pick('设计基准=445dp(Mate 80 Pro)', 'design baseline=445dp (Mate 80 Pro)')}');"""),
])

sub('lib/pages/drawer_page.dart', [
  ("AppLog.instance.op('导出主题配置：$name（共 $count 套）');",
   "AppLog.instance.op(L.pick('导出主题配置：$name（共 $count 套）', 'Theme config exported: $name ($count themes)'));"),
  ("title: Text('主题同名', style: TextStyle(fontSize: af(context, 14))),",
   "title: Text(L.t('主题同名'), style: TextStyle(fontSize: af(context, 14))),"),
])
