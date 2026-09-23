import '../app/app_version.dart';
import 'i18n.dart';

class S {
  S._();

  static String get appName => L.t('种子管理器');

  static String get appNameEn => L.t('Torrent Manager');

  static String get appNameLocalized => L.t('种子管理器');

  static String get versionPrefix => L.t('当前版本：V');

  static String appVersionText([String v = kAppVersion]) => '$versionPrefix$v';

  static String get ok => L.t('确定');
  static String get cancel => L.t('取消');

  static String get retry => L.t('重试');

  static String get relogin => L.t('重新登录');
  static String get edit => L.t('编辑');
  static String get execute => L.t('执行');
  static String get confirmExecute => L.t('确认执行');
  static String get change => L.t('更改');
  static String get delete => L.t('删除');
  static String get add => L.t('新增');
  static String get search => L.t('搜索');
  static String get restoreDefaults => L.t('恢复默认');
  static String get copyDone => L.t('内容已复制');
  static String get nameCopied => L.t('名称已复制');
  static String get all => L.t('全部');
  static String get unknown => L.t('未知');

  static String get execFailed => L.t('执行失败');
  static String get pleaseSelectTorrent => L.t('请选择种子');
  static String get warning => L.t('警告');
  static String get info => L.t('信息');
  static String get severe => L.t('严重');
  static String get normal => L.t('正常');
  static String get error => L.t('错误');

  static String torrentCount(int n) => L.pick('$n个种子', '$n torrents');
  static String selectedCount(int n) => L.pick('已选数量: $n', 'Selected: $n');
  static String countLabel(int n) => L.pick('数量: $n', 'Count: $n');

  static String get fieldSize => L.t('种子大小');
  static String get fieldProgress => L.t('种子进度');
  static String get fieldState => L.t('种子状态');
  static String get fieldCount => L.t('种子数量');
  static String get fieldTags => L.t('种子标签');
  static String get fieldCategory => L.t('种子分类');
  static String get fieldSiteName => L.t('站点名称');
  static String get fieldRatio => L.t('分享比率');
  static String get fieldSeeders => L.t('做种人数');
  static String get fieldLeechers => L.t('下载人数');
  static String get fieldEta => L.t('剩余时间');
  static String get fieldActiveTime => L.t('活动时间');
  static String get fieldAddedOn => L.t('添加时间');
  static String get fieldCompletionOn => L.t('完成时间');
  static String get fieldUpSpeed => L.t('上传速度');
  static String get fieldDlSpeed => L.t('下载速度');
  static String get fieldUploaded => L.t('上传总量');
  static String get fieldDownloaded => L.t('下载总量');

  static String get fieldSiteShort => L.t('站点');
  static String get fieldRatioShort => L.t('分享率');
  static String get fieldUpShort => L.t('上传');
  static String get fieldDlShort => L.t('下载');
  static String get fieldTotalUp => L.t('总计上传');
  static String get fieldTotalDl => L.t('总计下载');
  static String get fieldUpLimit => L.t('上传限速');
  static String get fieldDlLimit => L.t('下载限速');
  static String get fieldVerifyState => L.t('校验状态');
  static String get fieldSessionStats => L.t('会话统计');
  static String get fieldIp => L.t('IP地址');
  static String get fieldPath => L.t('路径');
  static String get fieldSelectedSize => L.t('已选大小: ');
  static String get fieldSort => L.t('排序: ');
  static String get fieldFreeSpace => L.t('剩余空间:');
  static String get fieldUpLoading => L.t('上传中');
  static String get fieldDlLoading => L.t('下载中');
  static String get fieldUpdating => L.t('更新中');

  static String get chartLabelDownload => L.t('下载');
  static String get chartLabelUpload => L.t('上传');
  static String get chartLabelVerifying => L.t('校验');
  static String get chartLabelServersOnline => L.t('服务器在线');

  static String get stSeeding => L.t('做种');
  static String get stPausedUp => L.t('暂停上传');
  static String get stPausedDl => L.t('暂停下载');
  static String get stMetaDl => L.t('下载元数据');
  static String get stQueued => L.t('等待状态');
  static String get stCheckingResume => L.t('检查恢复数据');
  static String get stAllocating => L.t('正在分配空间');
  static String get stMoving => L.t('正在移动');
  static String get stMissingFiles => L.t('数据文件丢失');
  static String get stNotWorking => L.t('未工作');

  static String get stPaused => L.t('已暂停');
  static String get stUnknownState => L.t('未知状态');

  static String get stVerifyColon => L.t('校验状态: ');

  static String get unitDay => L.t('天');
  static String get unitHour => L.t('小时');
  static String get unitMinute => L.t('分钟');
  static String get unitSecond => L.t('秒');
  static String get activeNever => L.t('添加后从未活跃');
  static String get activeJustNow => L.t('<1分钟前活跃');
  static String get activeAgo => L.t('前活跃');

  static String get setDelTorrentWithFiles => L.t('删种默认勾选删除文件');
  static String get setDelTorrentWithSub => L.t('删种默认勾选删除辅种');
  static String get setDelTorrentNoSubDelFiles => L.t('删种默认勾选无辅种则删除文件');

  static String get setNoLimitZero => L.t('设置0为不限速');
  static String get setNoLimitMinusOneShort => L.t('设置为-1代表不限制');
  static String get setRatioHelp => L.t('设置为-1表示无限制, -2表示使用全局限制\n设置分享比率为0等同于不做种\n任何一个限制达到标准即停止做种');
  static String get setSwitchToEnable => L.t('开启右侧开关后启用限制\n不开启则无限制');
  static String get setQueueSwitchHelp => L.t('开启"启用队列限制"后生效\n不开启则无限制');
  static String get setTempPathHelp => L.t('开启"启用临时路径"后生效');
  static String get setAltLimitHelp => L.t('开启"启用备用限速"后生效');
  static String get setPickFromBelow => L.t('可在下方已有路径中选取后自动填入');
  static String get setPickFromBelowNoAutoTmm => L.t('可在下方已有路径中选取后自动填入，选取需关闭自动种子管理');
  static String get setPickFromBelowPlain => L.t('可在下方路径中选取后自动填入');
  static String get setCategoryHelp => L.t('选择分类后点击更改\n若不选择任何分类,直接执行\'更改\'则为清除分类\n自动种子管理开启时，更改分类会移动文件到分类对应目录');
  static String get setCategoryAutoTmmHelp => L.t('种子如果开启了自动种子管理\n更改分类路径会移动文件到分类对应目录\n删除分类时，如果该分类下有种子，则会被移动到默认目录');
  static String get setTagDeleteHelp => L.t('选中后可删除标签，可多选\n');
  static String get setCategoryEditHelp => L.t('长按可编辑分类\n选中后可删除分类，可多选');
  static String get setAddNewLineHelp => L.t('添加多个时请换行');
  static String get setEnableQueueLimit => L.t('启用队列限制');

  static String get queueMoveTitle => L.t('队列顺序');
  static String get queueMoveTop => L.t('置顶');
  static String get queueMoveUp => L.t('上移');
  static String get queueMoveDown => L.t('下移');
  static String get queueMoveBottom => L.t('置底');

  static String get addLabelOptional => L.t('标签（可选）');
  static String get addLabelHelp => L.t('Transmission 用「标签」组织种子，可留空');
  static String get addPauseAfterAdd => L.t('添加后暂停');

  static String get actResume => L.t('继续');
  static String get actPause => L.t('暂停');
  static String get setUnfinishedExtQb => L.t('未完成文件添加扩展名.!qB');
  static String get setUnfinishedExtPart => L.t('未完成文件添加扩展名.part');

  static String get setEnableAltLimit => L.t('启用备用限速');
  static String get setEnableTempPath => L.t('启用临时路径');
  static String get setEnableAutoTmm => L.t('启用自动种子管理');
  static String get setPreallocate => L.t('为文件预分配磁盘空间');

  static String get themeCustom => L.t('自定义主题');
  static String get themeCurrentPrefix => L.t('当前主题: ');
  static String get themeFollowSystem => L.t('跟随系统');
  static String get themeLight => L.t('明亮模式');
  static String get themeDark => L.t('黑暗模式');

  static String get logPickServer => L.t('请选择服务器');
  static String get logPickServerHint => L.t('选择要查看的服务器后，这里显示它的日志');
  static String get logRangeAll => L.t('全部');
  static String get logRangeToday => L.t('今天');
  static String get logRange7d => L.t('近 7 天');
  static String get logRangeCustom => L.t('自定义区间');
  static String get logRangeHint => L.t('区间');
  static String get logRangeEmpty => L.t('该时间区间内没有日志');

  static String get logNoServer => L.t('暂无服务器，请先添加一台');

  static String get themePickMenuImage => L.t('菜单图片选择');
  static String get themeSaveBgError => L.t('保存背景错误: ');

  static String get themeFontColor => L.t('字体颜色');
  static String get themeFontColorAuto => L.t('跟随主题');
  static String get themeFontColorHelp => L.t(
      '「跟随主题」时字色随明暗自动切换：明亮模式近黑，黑暗模式近白。'
      '自定义后会固定使用该颜色，不再随明暗变化。');

  static String get themePresets => L.t('精选主题');

  static String get themePresetPinkCherry => L.t('粉樱');

  static String get themePresetWallpaperGroup => L.t('壁纸主题');

  static String get themeShowMore => L.t('查看更多');
  static String get themeShowLess => L.t('收起');

  static String get themeGlass => L.t('透明玻璃面板');
  static String get themeGlassHelp => L.t('快捷开关：打开把下方「透明度」设为 26%，关闭设回 0%。'
      '开启后卡片与面板变为半透明玻璃，背景图从卡片下透出。');

  static String get themeOpacity => L.t('透明度');
  static String get themeOpacityHelp => L.t(
      '统一调整卡片、面板、搜索框等带底衬组件的透明度：0% 为完全不透明（完全遮住背景图），'
      '100% 为完全透明（背景图完全透出）。主题页、日志页等正文直接铺在背景图上的页面有固定底衬，不受此项影响。');

  static String get accLocalNote => L.t('账号仅用于本机身份标识与本地备份归属，不发起任何网络请求。');
  static String get accSignedInPrefix => L.t('已登录账号: ');
  static String get accSignedOut => L.t('已退出账号');
  static String get accExit => L.t('退出登录');
  static String get accEmail => L.t('邮箱: ');

  static String get accLogin => L.t('登陆账号');

  static String get accLogoutConfirm => L.t('退出账号后仅清除本机账号标识，服务器配置与备份不受影响。确定要退出吗？');

  static String get copyUrlHint => L.t('链接已复制到剪贴板');

  static String get groupTheme => L.t('主题');
  static String get groupAbout => L.t('关于');

  static String get aboutCheckUpdate => L.t('检查更新');

  static String get srvAdd => L.t('添加服务器');
  static String get srvAdded => L.t('添加服务器成功: ');
  static String get srvEdited => L.t('修改服务器成功: ');
  static String get srvDeleted => L.t('删除服务器：');
  static String get srvEnterName => L.t('请输入服务器名称');
  static String get srvEnterAddress => L.t('请输入地址');
  static String get srvEnterValidNumber => L.t('请输入有效数字');

  static String get srvEnterUsername => L.t('请输入账号');
  static String get srvEnterPassword => L.t('请输入密码');

  static String get srvShowPassword => L.t('显示密码');
  static String get srvHidePassword => L.t('隐藏密码');

  static String get srvCredsRequired => L.t('请填写账号与密码');
  static String get srvHideAddress => L.t('隐藏服务器地址');

  static String get srvPrefTitle => L.t('服务器设置');

  static String get srvEditing => L.t('编辑服务器');
  static String get srvSave => L.t('保存');
  static String get srvSaveShort => L.t('添加');

  static String get srvHideDomain => L.t('隐藏服务器域名');
  static String get srvHidePort => L.t('屏蔽端口');
  static String get srvConfirmDeleteTitle => L.t('确认删除');
  static String get srvConfirmDeleteBody => L.t('您确定要删除该服务器吗？');

  static String get srvConnFail => L.t('无法连接到服务器，请检查服务器设置！');
  static String get srvConnTimeout => L.t('连接超时, 请检查网络或服务器');

  static String get srvIpBanned => L.t(
      'IP 已被服务器封禁（连续登录失败次数过多）。请到服务端解除封禁，或更换出口 IP 后再试。');

  static String get srvCredsMissing => L.t(
      '未填写账号或密码，已跳过登录以避免触发服务端封禁。请点「编辑」补全后重试。');

  static String get srvConfigIncomplete =>
      L.t('服务器配置不完整（地址或端口为空），已暂停自动重试。请点「编辑」补全。');

  static String get srvSuspended => L.t('已暂停重试');

  static String get srvSuspendedPrefix => L.t('已暂停自动重试：');

  static String get srvRetryOne => L.t('重试这台服务器');

  static String srvRetryExhausted(int n) =>
      L.pick('已连续失败 $n 次，自动重试已挂起。', 'Failed $n times in a row; auto-retry paused.');

  static String get srvPassKeepHint => L.t('留空则保持原密码');

  static String get srvPassWasEmpty => L.t('该服务器当前没有保存密码，请补填后再保存。');

  static String get upArrow => L.t('▲ ');
  static String get downArrow => L.t('▼ ');

  static String get ioUploadPrefix => L.t('上传：');
  static String get ioDownloadPrefix => L.t('下载：');

  static String get srvAddrInvalid => L.t('地址不对：请填主机名或完整 URL（例：192.168.1.5 或 https://ddns.example.com），不要只填 https');
  static String get srvSelectToAddTorrent => L.t('选择服务器以添加种子');
  static String get srvTimeout => L.t('连接超时, 请检查网络或服务器');
  static String get srvRefreshedAll => L.t('已重新刷新全部服务器');
  static String get srvManualRefresh => L.t('执行手动刷新，重新获取所有服务器数据');

  static String get qbSetServerLimit => L.t('设置服务器全局限速成功: ');
  static String get qbSetServerLimitFail => L.t('setServerLimit 设置服务器全局限速失败: ');
  static String get qbSetAltLimit => L.t('设置服务器备用限速成功: ');
  static String get qbSetAltLimitFail => L.t('setServerAltLimit 设置服务器备用限速失败: ');
  static String get qbSetRatio => L.t('更改 做种限制 成功: ');
  static String get qbSetRatioFail => L.t('setServerRatio 更改 做种限制 失败: ');
  static String get qbSetSavePath => L.t('更改默认保存路径成功: ');
  static String get qbSetSavePathFail => L.t('setSavePath 更改默认保存路径失败: ');
  static String get qbSetTempPath => L.t('更改 临时路径 成功: ');
  static String get qbSetTempPathFail => L.t('setTempPath 更改 临时路径 失败: ');
  static String get qbSetMaxConnec => L.t('更改 连接限制 成功: ');
  static String get qbSetMaxConnecFail => L.t('setMaxConnec 更改 连接限制 失败: ');
  static String get qbSetQueueing => L.t('更改 队列限制 成功: ');
  static String get qbSetQueueingFail => L.t('setServerQueueing 更改 队列限制 失败: ');
  static String get qbSetPreallocate => L.t('更改 为文件预分配磁盘空间 成功: ');
  static String get qbSetPreallocateFail => L.t('setPreallocateAll 更改 为文件预分配磁盘空间 失败: ');
  static String get qbSetAutoTmm => L.t('更改 启用自动种子管理 成功: ');
  static String get qbSetAutoTmmFail => L.t('setAutoTmmEnabled 更改 启用自动种子管理 失败: ');
  static String get qbSetIncompleteQb => L.t('更改 未完成文件添加扩展名".!qB" 成功: ');
  static String get qbSetIncompleteQbFail => L.t('setIncompleteFilesExt 更改 未完成文件添加扩展名".!qB" 失败: ');
  static String get qbSetIncompletePart => L.t('更改 未完成文件添加扩展名".part" 成功: ');
  static String get qbSetIncompletePartFail => L.t('setIncompleteFilesExt 更改 未完成文件添加扩展名".part" 失败: ');

  static String get tAdded => L.t('添加种子成功: ');
  static String get tAddFailed => L.t('添加种子失败');
  static String get tNoLinkOrFile => L.t('未添加种子链接或种子文件');
  static String get tFilePrioOk => L.t('更改文件优先级成功, 名称:');
  static String get tRecheckOk => L.t('已执行重新校验, 名称: ');
  static String get tReannounceOk => L.t('已执行重新汇报, 名称: ');

  static String get tagCreatedPlain => L.t('已创建标签');
  static String get tagRemovedPlain => L.t('已删除标签');
  static String get catCreatedPlain => L.t('已创建分类');
  static String get catRemovedPlain => L.t('已删除所选分类');
  static String get catNameEmpty => L.t('类别名称为空');

  static String get remove => L.t('移除');

  static String get filePathUnavailable => L.t('文件路径不可用，请重新选择');

  static String get tAddBatchPartial => L.t('添加完成，部分失败');

  static String get tAddBatchFailList => L.t('以下条目添加失败');

  static String get trkAddAllHelp => L.t('执行后将新Tracker添加到所有已选种子');
  static String get trkDeleteHelp => L.t('执行后遍历已选种子的Tracker, 查询输入的原Tracker是否存在,\n若存在则执行删除操作, 不存在则跳过');
  static String get trkReplaceHelp => L.t('执行后遍历已选种子的Tracker, 查询输入的原Tracker是否存在,\n若存在则执行替换操作, 不存在则跳过');
  static String get trkAddTitle => L.t('添加Tracker(');
  static String get trkEditTitle => L.t('修改Tracker(');
  static String get trkDeleteTitle => L.t('删除Tracker(');
  static String get trkDoAdd => L.t('执行添加tracker');
  static String get trkDoEdit => L.t('执行修改tracker');
  static String get trkDoDelete => L.t('执行删除tracker');
  static String get trkNone => L.t('暂无Tracker数据');
  static String get trkCopied => L.t('tracker已复制');
  static String get trkParseFailed => L.t('解析 Tracker 失败: ');
  static String get trkEditInvalidUrl => L.t('修改tracker失败, 不是有效的URL, 名称:');
  static String get trkEditOk => L.t('修改tracker成功, 名称:');
  static String get trkDelNotFound => L.t('删除tracker失败, 未找到tracker, 名称:');
  static String get trkDelOk => L.t('删除tracker成功, 名称:');
  static String get trkAddOk => L.t('添加tracker成功, 名称:');

  static String get trkEditNotFound =>
      L.t('修改tracker失败, 未找到原tracker, 名称:');

  static String get noTrId =>
      L.t('该种子缺少 Transmission 任务 ID，无法执行此操作');

  static String get noServer => L.t('未选择服务器');

  static String get bkExportOk => L.t('导出备份文件成功!');
  static String get bkRestoreOk => L.t('恢复配置文件成功, 已恢复服务器列表:\n');
  static String get bkRestoreFail => L.t('恢复配置文件失败, 错误信息: ');

  static String get bkPortableExport => L.t('导出便携备份到…');
  static String get bkPortableImport => L.t('导入便携备份');
  static String get bkPortableHint => L.t(
      '便携备份含服务器密码，用你设置的口令加密，可在任意设备导入；'
      '下方的明文 JSON 不含密码，只适合本机留档。');
  static String get bkPortableExportTitle => L.t('设置便携备份口令');
  static String get bkPortableImportTitle => L.t('输入便携备份口令');
  static String get bkPortableExportBody => L.t(
      '这份备份含服务器地址与密码。口令用于加密文件，请牢记 —— '
      '口令丢失后文件将无法解开（本应用不保存口令，也无法找回）。');
  static String get bkPortableImportBody => L.t('输入导出这台设备时设置的口令。');
  static String get bkPortablePassphrase => L.t('口令');
  static String get bkPortableConfirm => L.t('确认口令');
  static String get bkPortableTooShort => L.t('口令至少 6 位');
  static String get bkPortableMismatch => L.t('两次输入的口令不一致');
  static String get bkPortableExportOk => L.t('已导出便携备份（含密码，口令加密）');
  static String bkPortableImportOk(int n) =>
      L.pick('已导入 $n 台服务器（含密码）', 'Imported $n servers (with passwords)');

  static String get bkPortableWrongPass => L.t('口令不正确，或文件已被修改/损坏');

  static String get bkPortableNotPortable => L.t(
      '这不是便携备份文件。便携备份请用「导出便携备份到…」生成（文件内含 portable 标识）。');

  static String get bkJsonImportNote => L.t(
      '粘贴从其他设备导出的 JSON。⚠️ 该格式不含密码：同 id 的服务器保留本机已有密码，'
      '新增的服务器需要导入后手动补填密码。要连密码一起迁移请用「便携备份」。');
  static String get bkJsonExportNote =>
      L.t('已复制到剪贴板（含服务器地址与用户名，不含密码）');

  static String get btExportTorrent => L.t('导出种子');
  static String get btExportOk => L.t('导出种子成功!');
  static String get btExportFail => L.t('导出种子失败');
  static String get btQbTooOld => L.t('QB版本过低不支持导出种子');

  static String get btExportTrUnsupported =>
      L.t('导出 .torrent 仅 qBittorrent 支持（Transmission 的 RPC 没有这个接口）');
  static String get btExportFailPrefix => L.t('exportTorrent 导出种子失败: ');

  static String get logTitle => L.t('日志');
  static String get logRefreshed => L.t('已刷新日志');
  static String get logQbFetchFailed => L.t('getQbLogs 获取日志失败: ');
  static String get noTraffic => L.t('暂无流量活动');

  static String get themeExport => L.t('导出主题配置');
  static String get themeImport => L.t('导入主题配置');
  static String get themeImportSub => L.t('从 .json 文件还原整套主题');
  static String get themeExporting => L.t('正在导出…');
  static String get themeImporting => L.t('正在导入…');
  static String get themeExportCountPrefix => L.t('共 ');
  static String get themeExportCountSuffix => L.t(' 套自定义主题');

  static String get themeExportEmpty => L.t('还没有已保存的自定义主题');
  static String get themeExportOkPrefix => L.t('已导出 ');
  static String get themeExportOkInfix => L.t(' 套主题 → ');
  static String get themeExportFailedPrefix => L.t('导出主题失败：');
  static String get themeImportCancelled => L.t('已取消导入');

  static String get themeImportBadSource => L.t('导入失败：这不是 TorrentManager 主题配置文件');
  static String get themeImportBadSourceHint => L.t('请确认选中的是本应用导出的 .json 文件（内含 "torrentmanager-theme-pack" 标识）。');
  static String themeImportTooNew(int file, int app) => L.pick(
      '导入失败：文件来自更新的版本（文件 v$file > 应用 v$app）',
      'Import failed: the file comes from a newer version (file v$file > app v$app)');
  static String get themeImportTooNewHint => L.t('请先升级到最新版 TorrentManager，再导入这个文件。');
  static String get themeImportEmpty => L.t('导入失败：文件里没有任何主题');
  static String get themeImportEmptyHint => L.t('文件结构正确，但 themes 列表为空 —— 可能导出时还没有保存任何自定义主题。');
  static String themeImportItemSkipped(int i, String reason) => L.pick(
      '第 $i 套主题格式不正确，已跳过（$reason）',
      'Theme #$i has an invalid format and was skipped ($reason)');
  static String themeImportAllBad(int n) => L.pick(
      '导入失败：$n 套主题均无法解析',
      'Import failed: none of the $n themes could be parsed');
  static String get themeImportAllBadHint => L.t('逐条解析都失败了。文件可能被其它程序改写过，可尝试重新导出一份。');
  static String get themeImportReadFailed => L.t('读取文件失败');
  static String themeImportOk(int n) =>
      L.pick('已导入 $n 套主题', 'Imported $n themes');
  static String themeImportPartial(int ok, int skipped) => L.pick(
      '已导入 $ok 套主题，跳过 $skipped 套',
      'Imported $ok themes, skipped $skipped');

  static String get themeImportKeepBoth => L.t('保留两者');
  static String get themeImportOverwrite => L.t('覆盖');

  static String get themeImportNameSuffix => L.t('（导入）');
  static String themeImportConflictBody(int n) => L.pick(
      '有 $n 套主题与本机已保存的主题同名。选择处理方式：',
      '$n themes share a name with ones already saved. Choose how to handle:');

  static String get logSelectMode => L.t('选择');
  static String get logSelectAll => L.t('全选');
  static String get logInvert => L.t('反选');
  static String get logClear => L.t('清空日志');
  static String logSelectedCount(int n) =>
      L.pick('已选择 $n 条', '$n selected');
  static String logCopyCount(int n) => L.pick('复制 $n 条', 'Copy $n');
  static String get logExportSelected => L.t('导出所选');
  static String get logExportAll => L.t('导出全部');
  static String logCopied(int n) =>
      L.pick('已复制 $n 条日志', 'Copied $n log lines');
  static String logExportOk(int n) =>
      L.pick('已导出 $n 条 → ', 'Exported $n → ');

  static String logExportPrivacyOff(int n) => L.pick(
      '已导出 $n 条（隐私模式已关闭，文件含真实地址）',
      'Exported $n (privacy mode off; the file contains real addresses)');
  static String get logExportFailedPrefix => L.t('导出失败：');
  static String get logExportCancelled => L.t('已取消导出');
  static String get logExportFileName => L.t('文件名');

  static String get logFilterEntry => L.pick('按服务器筛选', 'Filter by server');

  static String get logFilterTitle => L.pick('按服务器筛选', 'Filter by server');

  static String get logFilterHideSystem =>
      L.pick('隐藏系统日志', 'Hide system logs');

  static String get logFilterHideSystemHint => L.pick(
      '应用启动 / 复制 / 点击卡片 / 设备启动等与服务器无关的日志',
      'App launch / copy / card tap / device boot — logs not tied to a server');

  static String get logFilterServerSection => L.pick('服务器', 'Servers');

  static String get logFilterNoneHint =>
      L.pick('不勾选任何一台 = 不筛选', 'No selection = no filtering');

  static String get logFilterDone => L.pick('完成', 'Done');

  static String get logFilterReset => L.pick('清空', 'Reset');

  static String logFilterSummary(String names) =>
      L.pick('只看 $names', 'Only $names');

  static String get logFilterSummaryHideSystem =>
      L.pick('已隐藏系统日志', 'System logs hidden');

  static String get logFilterEmpty =>
      L.pick('当前筛选条件下没有日志', 'No logs match the current filter');

  static String get logFilterResetAction => L.pick('清除筛选', 'Clear filter');

  static String logFilterCount(int n) => L.pick('$n 条', '$n lines');

  static String get logFilterNoServer =>
      L.pick('暂无可筛选的服务器', 'No servers to filter');

  static String get logExportFiltered =>
      L.pick('导出筛选结果', 'Export filtered');

  static String get netTooManyRedirects => L.t('RedirectInterceptor: 超过最大重定向次数');
  static String get noFileSelected => L.t('未选择文件');
  static String get pleaseSelectFile => L.t('请选择文件');

  static String get pleaseSelectCategory => L.t('请选择要删除的分类');
  static String get pleaseSelectTag => L.t('请选择要删除的标签');
  static String get filterCleared => L.t('已清除筛选条件');
  static String get querySubTorrents => L.t('查询辅种');
  static String get hasUpdate => L.t('有更新');

  static String get noUpdate => L.t('已是最新版本');

  static String get checkingUpdate => L.t('正在检查更新…');
  static String get peerBanOk => L.t('禁用Peers成功,IP:');
  static String get peerBanFail => L.t('禁用Peers失败');

  static String get peerBanTitle => L.t('封禁 Peer');

  static String get peerCopyIp => L.t('复制 IP');

  static String get peerCopyIpPort => L.t('复制 IP:端口');

  static String peerCopied(String ip) =>
      L.pick('已复制：$ip', 'Copied: $ip');

  static String peerBanConfirm(String target) =>
      L.pick('确定要封禁 $target 吗？', 'Ban $target?');

  static String get peerBanNoDuration => L.pick(
        'qBittorrent 的封禁接口不支持时长：封禁后立即生效，需到服务端手动解除。',
        'qBittorrent has no ban-duration option: the ban takes effect '
            'immediately and must be lifted manually on the server.');

  static String get privacyTitle => L.t('隐私政策');
  static String get termsTitle => L.t('用户协议');

  static String get aboutGroup => L.t('关于');

  static String get openSourceTitle => L.t('开源说明');

  static String get openSourceBody => L.t(
      'TorrentManager 是自由开源软件，以 MIT License 发布。\n'
      '\n'
      '一、源码与发布\n'
      '项目主页：$kProjectUrl\n'
      '发布页（预编译 APK）：$kReleasesUrl\n'
      '\n'
      '二、许可条款（摘要）\n'
      '你可以自由使用、复制、修改、合并、出版发行、散布、再许可和/或销售'
      '本软件的副本，只需在所有副本中包含上述版权声明和本许可声明。软件'
      '按"现状"提供，不包含任何明示或默示的担保，作者不对任何索赔、损害'
      '或其他责任负责。全文见仓库根目录的 LICENSE 文件。\n'
      '\n'
      '三、第三方组件\n'
      '本应用构建于 Flutter / Dart 与以下开源项目之上：GetX（状态管理与'
      '路由）、Dio 与 dio_cookie_manager / cookie_jar（HTTP 客户端与'
      'Cookie）、pointycastle（AES-GCM 加密）、flutter_secure_storage 与'
      'shared_preferences / path_provider（本机存储）、file_picker（文件'
      '选择）、fl_chart（图表）、intl（数字与日期格式化）。它们各自按其'
      '原许可证授权，完整清单见仓库的 pubspec.yaml 与 pubspec.lock。\n'
      '\n'
      '四、第三方标识与商标\n'
      'assets 中的 qbittorrent / transmission 标识版权归各自项目所有，'
      '不适用本仓库的 MIT 许可，仅用于在界面上标识所连接的服务器类型。'
      '本项目与 qBittorrent、Transmission 无隶属、赞助或背书关系，是独立'
      '开发的第三方客户端，仅通过二者公开的 RPC 接口通信。');

  static String startupUpdateBody(String latest) =>
      "${L.t('发现新版本 V')}$latest${L.pick('，当前版本 ', ', current ')}$kAppVersion\n"
      "\n${L.t('本应用只会在这里提醒一次，不会自动下载或安装任何东西。')}\n"
      "\n${L.t('发布页：')}$kReleasesUrl";

  static String get copyReleaseLink => L.t('复制发布页地址');

  static String get privacyBody => L.t(
      '本应用是一个纯本地工具，不设服务端、不收集账号。\n'
      '\n'
      '一、存储在你设备上的数据\n'
      '服务器地址、端口、账号与密码只保存在本机；密码经加密后存储，'
      '不会随日志或崩溃报告离开设备。你可以随时删除服务器条目，删除后'
      '本机不再留存对应凭据。\n'
      '\n'
      '二、对外发起的请求\n'
      '除你填写的下载服务器之外，本应用只会在两种情况下访问外部网络：\n'
      '1. IP 归属地查询 —— 详情页显示 Peer 地理位置时，会把该 Peer 的'
      'IP 发送给公共归属地查询服务（如 ip-api.com、ip9.com.cn 等；应用'
      '会在多个接口间分散请求，避免过量访问单一服务）。请求只包含该 IP '
      '本身，不附带任何设备信息；内网与保留地址不发。\n'
      '2. 版本更新检查 —— 每次启动会自动检查一次（仅比对版本号，'
      '发现新版才弹一次提醒，你也可以在抽屉里手动点「检查更新」）。'
      '它访问的是本应用 GitHub 仓库的发布接口（api.github.com），'
      '只读取最新版本号，不发送任何设备信息或使用数据；本应用'
      '不会自动下载或安装 APK，是否更新、何时更新完全由你决定。\n'
      '除此之外，你的种子列表、文件清单、Tracker 地址都不会被上传到任何地方。\n'
      '\n'
      '三、日志\n'
      '运行日志保存在本机，可手动导出或清空。日志默认对域名、IP 与端口'
      '打码，登录口令与会话凭证不会写入日志。\n'
      '\n'
      '四、备份\n'
      '导出备份时可选择剔除密码；便携备份以口令加密，口令由你自行保管，'
      '丢失后无法恢复。\n'
      '\n'
      '五、开源\n'
      '本应用是开源软件（MIT License），代码公开可审阅：\n'
      '$kProjectUrl\n'
      '所有上述行为你都可以在源码里自行核对。');

  static String get termsBody => L.t(
      '一、本应用是什么\n'
      'TorrentManager 是一个下载器远程管理客户端。它本身不下载、不存储、'
      '不传播任何内容，只是把你自己的 qBittorrent / Transmission 服务端'
      '界面搬到手机上。\n'
      '\n'
      '二、你的责任\n'
      '你连接哪台服务器、用它下载什么，由你自行决定并承担相应责任。'
      '请遵守所在地区的法律法规与所在站点的规则，不要用于下载或传播'
      '侵犯他人权利的内容。\n'
      '\n'
      '三、账号与凭据\n'
      '服务器账号密码由你填写并只保存在本机（加密存储）。请妥善保管设备'
      '与备份文件；因设备丢失、备份文件外泄造成的损失由你自行承担。\n'
      '\n'
      '四、免责\n'
      '本应用按"现状"提供，不对下载内容的合法性、完整性或可用性作任何'
      '担保，也不对因使用本应用导致的直接或间接损失承担责任。\n'
      '\n'
      '五、删除操作不可撤销\n'
      '删除下载任务、勾选"同时删除本地文件"等操作会直接作用于你的服务端，'
      '执行前请确认。误删的数据本应用无法帮你找回。\n'
      '\n'
      '六、开源\n'
      '本应用是开源软件，以 MIT License 发布，源码见：\n'
      '$kProjectUrl\n'
      '你可以自行审阅代码、提出缺陷或自行构建。自行构建的版本不属于本'
      '应用官方发布，由构建者自行承担使用风险。');

  static String get langTitle => L.t('语言');
  static String get langZh => L.t('简体中文');

  static const String langEn = 'English';
  static String get langSwitched => L.t('已切换语言');

  static String get langSwitchHint => L.t('点击切换界面语言');

  static String get langDialogBody => L.t('切换后立即生效，并记住这次选择。');

  static String get groupShare => L.t('分享与导出');
  static String get shareSubtitle => L.t('备份到本机 · 恢复 · 导入导出 JSON');
  static String get menuTitle => L.t('菜单');
  static String get renameTitle => L.t('重命名');
  static String get renameField => L.t('主题名称');
  static String get deleteCustomThemeTitle => L.t('删除自定义主题');

  static String deleteCustomThemeBody(String name) =>
      "${L.t('确定删除「')}$name${L.pick('」？此操作不可撤销。', '”? This cannot be undone.')}";

  static String deletedToast(String name) =>
      "${L.t('已删除「')}$name${L.pick('」', '"')}";
  static String renamedToast(String name) =>
      "${L.t('已重命名为「')}$name${L.pick('」', '"')}";
}
