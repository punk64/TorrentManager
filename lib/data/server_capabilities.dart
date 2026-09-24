import 'models/server_data.dart';

/// 服务端**按版本**的能力判定（第 67 轮 V2~V7 的地基）。
///
/// ★ 为什么不用「服务器类型」一刀切：同一个 qBittorrent 4.x / 5.x 之间、
///   Transmission 3.00 / 4.0 / 4.1 之间的接口差异**比两端之间还大**
///   （详见 `文档指南/第67轮-QB与TR接口版本兼容梳理.md`）。
///
/// ★ 判据口径：
///   - qB：用 **`app/webapiVersion`**（如 `2.11.4`），**不要用主版本号**。
///     路径一直是 `/api/v2`，只有 WebAPI 版本在递增 ⇒ 主版本 ≥5 的判断会在
///     4.6（WebAPI 2.11.x）等版本上误判。
///   - TR：用 `session-get` 的 `version`（如 `4.1.0`）。
///
/// ★ 版本取不到时（老服务端 / 探测失败）走 [unknownAs]（默认 **true = 乐观**）：
///   保持功能可达，由写操作侧的 404/405 自适应兜底。UI 只用它决定是否**提示**，
///   不要用它决定能否点击（否则版本探测一失败整块功能就消失）。
///
/// 全是纯静态函数 ⇒ 可以直接单测，不依赖网络与 GetX。
class ServerCapabilities {
  ServerCapabilities._();

  // ===== qBittorrent 门槛（WebAPI 版本） =====

  /// `torrents/setTags`（整体替换）门槛：qB 5.1.0 / WebAPI 2.11.4。
  ///
  /// 低于此版本 ⇒ 必须降级为 `addTags` + `removeTags` 差集提交。
  static const String qbSetTagsMinApi = '2.11.4';

  /// `torrents/export`（导出 .torrent）门槛：qB 4.5.0 / WebAPI 2.8.14。
  static const String qbExportMinApi = '2.8.14';

  /// `torrents/info` 的 `isPrivate` 字段门槛：qB 5.0.0 / WebAPI 2.11.0。
  static const String qbPrivateMinApi = '2.11.0';

  // ===== Transmission 门槛（应用版本） =====

  /// `sequential_download` 字段门槛：TR **4.1.0**。
  static const String trSequentialMinVer = '4.1.0';

  /// `trackerList`（替代废弃的 trackerAdd/Remove/Replace）门槛：TR 4.0.0。
  static const String trTrackerListMinVer = '4.0.0';

  /// `free-space` 方法（替代废弃的 `download-dir-free-space`）门槛：TR 4.0.0。
  static const String trFreeSpaceMethodMinVer = '4.0.0';

  /// 解析版本号为整数段：兼容 `v5.1.2` / `4.1.0-beta.1` / `2.11` / `3` / 空串。
  ///
  /// 规则：去掉前缀 `v`、只保留第一个 `-`/`+` 之前的「纯数字点分段」，
  /// 非数字段（如 `beta` 后的内容）一律忽略 ⇒ `4.1.0-beta.1` 视为 `4.1.0`。
  static List<int> parseVersion(String? raw) {
    final String v = (raw ?? '').trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (v.isEmpty) return const <int>[];
    final int cut = v.indexOf(RegExp(r'[-+]'));
    final String core = cut < 0 ? v : v.substring(0, cut);
    final List<int> out = <int>[];
    for (final String seg in core.split('.')) {
      final int? n = int.tryParse(seg.trim());
      if (n == null) break;
      out.add(n);
    }
    return out;
  }

  /// 比较两个版本号：a > b 返回正数，相等 0，a < b 负数。
  /// 位数不等时缺位按 0 处理（`2.11` == `2.11.0`）。
  static int compare(String? a, String? b) {
    final List<int> x = parseVersion(a);
    final List<int> y = parseVersion(b);
    final int len = x.length > y.length ? x.length : y.length;
    for (int i = 0; i < len; i++) {
      final int p = i < x.length ? x[i] : 0;
      final int q = i < y.length ? y[i] : 0;
      if (p != q) return p - q;
    }
    return 0;
  }

  /// `version >= target`？版本取不到（空串）时返回 [unknownAs]。
  static bool atLeast(
    String? version,
    String target, {
    bool unknownAs = true,
  }) {
    if (parseVersion(version).isEmpty) return unknownAs;
    return compare(version, target) >= 0;
  }

  // ===== qB 能力 =====

  /// 能否用 `torrents/setTags` 整体替换标签；否则走 addTags/removeTags 差集。
  static bool qbCanSetTags(String? api, {bool unknownAs = true}) =>
      atLeast(api, qbSetTagsMinApi, unknownAs: unknownAs);

  /// 能否导出 .torrent。
  static bool qbCanExport(String? api, {bool unknownAs = true}) =>
      atLeast(api, qbExportMinApi, unknownAs: unknownAs);

  /// `torrents/info` 是否带 `isPrivate`（决定「私有种子」标记能否显示）。
  static bool qbHasPrivateFlag(String? api, {bool unknownAs = false}) =>
      atLeast(api, qbPrivateMinApi, unknownAs: unknownAs);

  // ===== TR 能力 =====

  /// 是否支持种子级「顺序下载」。
  static bool trCanSequential(String? version, {bool unknownAs = true}) =>
      atLeast(version, trSequentialMinVer, unknownAs: unknownAs);

  /// 是否支持 `trackerList`（4.0 起 trackerAdd/Remove/Replace 已废弃）。
  static bool trCanTrackerList(String? version, {bool unknownAs = false}) =>
      atLeast(version, trTrackerListMinVer, unknownAs: unknownAs);

  /// 是否支持 `free-space` 方法（4.0 起 `download-dir-free-space` 已废弃）。
  static bool trHasFreeSpaceMethod(String? version, {bool unknownAs = false}) =>
      atLeast(version, trFreeSpaceMethodMinVer, unknownAs: unknownAs);

  /// 给 UI 用的一站式取值：按当前服务器返回「能力包」。
  ///
  /// [appVersion] = `ServerController.serverVersion[id]`（QB 应用版本 / TR 版本），
  /// [apiVersion] = `ServerController.serverApiVersion[id]`（QB 的 webapiVersion；TR 可空）。
  static CapabilitySet of(
    ServerData? s, {
    String? appVersion,
    String? apiVersion,
  }) {
    if (s == null) return const CapabilitySet();
    final String app = appVersion ?? '';
    final String api = apiVersion ?? '';
    if (s.isQbittorrent) {
      return CapabilitySet(
        isQb: true,
        setTagsReplace: qbCanSetTags(api),
        exportTorrent: qbCanExport(api),
        privateFlag: qbHasPrivateFlag(api),
        sequentialDownload: true,
        superSeeding: true,
        forceStart: true,
        category: true,
        queuePosition: false,
        bandwidthPriority: false,
        // qB 的 tracker 走 addTrackers/removeTrackers/editTrackers（按 URL），
        // 与 TR 的 trackerList 无关 ⇒ 恒 false，别误用。
        trackerList: false,
        freeSpaceMethod: false,
      );
    }
    return CapabilitySet(
      isQb: false,
      setTagsReplace: true,
      exportTorrent: false,
      privateFlag: true,
      // ★ V6：顺序下载是 TR 4.1 才有的字段，按版本显示而不是按服务器类型隐藏。
      sequentialDownload: trCanSequential(app),
      superSeeding: false,
      forceStart: false,
      category: false,
      queuePosition: true,
      bandwidthPriority: true,
      // ★ V5 / V7：4.0 起 tracker 三件套与 `download-dir-free-space` 都废弃，
      //   按版本切到 trackerList / free-space 新接口（详见 compat.md）。
      trackerList: trCanTrackerList(app),
      freeSpaceMethod: trHasFreeSpaceMethod(app),
    );
  }
}

/// 当前服务器的能力包：UI 直接读布尔值，不必自己拼版本判断。
class CapabilitySet {
  const CapabilitySet({
    this.isQb = false,
    this.setTagsReplace = true,
    this.exportTorrent = false,
    this.privateFlag = false,
    this.sequentialDownload = false,
    this.superSeeding = false,
    this.forceStart = false,
    this.category = false,
    this.queuePosition = false,
    this.bandwidthPriority = false,
    this.trackerList = false,
    this.freeSpaceMethod = false,
  });

  /// qBittorrent（否则按 Transmission 处理）。
  final bool isQb;

  /// 标签能否整体替换（qB 5.1+）；false ⇒ 走 addTags/removeTags 差集。
  final bool setTagsReplace;

  /// 能否导出 .torrent（qB 4.5+）。
  final bool exportTorrent;

  /// 是否带私有种子标记。
  final bool privateFlag;

  /// 是否支持种子级顺序下载。
  final bool sequentialDownload;

  /// 是否支持超级做种。
  final bool superSeeding;

  /// 是否支持强制做种（TR 没有；其 `honorsSessionLimits` 语义完全不同）。
  final bool forceStart;

  /// 是否支持分类（TR 无分类）。
  final bool category;

  /// 是否支持精确队列位置（TR 有；qB 的 priority 语义不同）。
  final bool queuePosition;

  /// 是否支持带宽优先级（TR 有）。
  final bool bandwidthPriority;

  /// V5：tracker 增删改能否走 `trackerList` 整体替换（TR 4.0+）。
  ///
  /// false ⇒ 走 4.0 起已废弃、但 4.x 仍可用的 trackerAdd/Remove/Replace。
  final bool trackerList;

  /// V7：剩余空间能否用 `free-space` 方法按路径查（TR 4.0+）。
  ///
  /// false ⇒ 仍读 torrent-get 的 `downloadDirFreeSpace` 字段（4.0 起废弃）。
  final bool freeSpaceMethod;
}
