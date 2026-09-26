import 'models/server_data.dart';

class ServerCapabilities {
  ServerCapabilities._();

  static const String qbSetTagsMinApi = '2.11.4';

  static const String qbExportMinApi = '2.8.14';

  static const String qbPrivateMinApi = '2.11.0';

  static const String qbAddPeersMinApi = '2.8.2';

  static const String qbRenameFileMinApi = '2.8.15';

  static const String trSequentialMinVer = '4.1.0';

  static const String trTrackerListMinVer = '4.0.0';

  static const String trFreeSpaceMethodMinVer = '4.0.0';

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

  static bool atLeast(
    String? version,
    String target, {
    bool unknownAs = true,
  }) {
    if (parseVersion(version).isEmpty) return unknownAs;
    return compare(version, target) >= 0;
  }

  static bool qbCanSetTags(String? api, {bool unknownAs = true}) =>
      atLeast(api, qbSetTagsMinApi, unknownAs: unknownAs);

  static bool qbCanExport(String? api, {bool unknownAs = true}) =>
      atLeast(api, qbExportMinApi, unknownAs: unknownAs);

  static bool qbHasPrivateFlag(String? api, {bool unknownAs = false}) =>
      atLeast(api, qbPrivateMinApi, unknownAs: unknownAs);

  static bool qbCanAddPeers(String? api, {bool unknownAs = false}) =>
      atLeast(api, qbAddPeersMinApi, unknownAs: unknownAs);

  static bool qbCanRenameFile(String? api, {bool unknownAs = false}) =>
      atLeast(api, qbRenameFileMinApi, unknownAs: unknownAs);

  static bool trCanSequential(String? version, {bool unknownAs = true}) =>
      atLeast(version, trSequentialMinVer, unknownAs: unknownAs);

  static bool trCanTrackerList(String? version, {bool unknownAs = false}) =>
      atLeast(version, trTrackerListMinVer, unknownAs: unknownAs);

  static bool trHasFreeSpaceMethod(String? version, {bool unknownAs = false}) =>
      atLeast(version, trFreeSpaceMethodMinVer, unknownAs: unknownAs);

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

        trackerList: false,
        freeSpaceMethod: false,
        renameFile: qbCanRenameFile(api),
        addPeers: qbCanAddPeers(api),
        pieceStates: true,
      );
    }
    return CapabilitySet(
      isQb: false,
      setTagsReplace: true,
      exportTorrent: false,
      privateFlag: true,

      sequentialDownload: trCanSequential(app),
      superSeeding: false,
      forceStart: false,
      category: false,
      queuePosition: true,
      bandwidthPriority: true,

      trackerList: trCanTrackerList(app),
      freeSpaceMethod: trHasFreeSpaceMethod(app),
      renameFile: true,
      addPeers: false,
      pieceStates: true,
    );
  }
}

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
    this.renameFile = false,
    this.addPeers = false,
    this.pieceStates = false,
  });

  final bool isQb;

  final bool setTagsReplace;

  final bool exportTorrent;

  final bool privateFlag;

  final bool sequentialDownload;

  final bool superSeeding;

  final bool forceStart;

  final bool category;

  final bool queuePosition;

  final bool bandwidthPriority;

  final bool trackerList;

  final bool freeSpaceMethod;

  /// 文件/文件夹重命名（qB renameFile 2.8.15+ / TR rename-path）
  final bool renameFile;

  /// 手动添加 Peer（仅 qB addPeers 2.8.2+）
  final bool addPeers;

  /// 分块状态热力图（qB pieceStates / TR pieces 位图）
  final bool pieceStates;
}
