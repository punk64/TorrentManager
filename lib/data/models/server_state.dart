import '../../utils/formatter.dart';

class ServerState {
  ServerState({
    this.dlInfoSpeed = 0,
    this.upInfoSpeed = 0,
    this.dlInfoData = 0,
    this.upInfoData = 0,
    this.alltimeDl = 0,
    this.alltimeUl = 0,
    this.dlRateLimit = 0,
    this.upRateLimit = 0,
    this.freeSpaceOnDisk = 0,
    this.globalRatio = 0,
    this.connectionStatus = 'unknown',
    this.dhtNodes = 0,
    this.queueing = false,
    this.useAltSpeedLimits = false,
    this.totalPeerConnections = 0,
    this.refreshInterval = 1500,
    this.queuedIoJobs = 0,
    List<int>? dlHistory,
    List<int>? upHistory,
  })  : dlHistory = dlHistory ?? <int>[],
        upHistory = upHistory ?? <int>[];

  int dlInfoSpeed;

  int upInfoSpeed;

  int dlInfoData;

  int upInfoData;

  int alltimeDl;

  int alltimeUl;

  int dlRateLimit;

  int upRateLimit;

  int freeSpaceOnDisk;

  double globalRatio;

  String connectionStatus;

  int dhtNodes;
  bool queueing;
  bool useAltSpeedLimits;
  int totalPeerConnections;

  int refreshInterval;

  int queuedIoJobs;

  final List<int> dlHistory;
  final List<int> upHistory;

  static const int maxHistory = 60;

  factory ServerState.fromJson(Map<String, dynamic> json) {
    return ServerState(
      dlInfoSpeed: Formatter.getInt(json, 'dl_info_speed'),
      upInfoSpeed: Formatter.getInt(json, 'up_info_speed'),
      dlInfoData: Formatter.getInt(json, 'dl_info_data'),
      upInfoData: Formatter.getInt(json, 'up_info_data'),
      alltimeDl: Formatter.getInt(json, 'alltime_dl'),
      alltimeUl: Formatter.getInt(json, 'alltime_ul'),
      dlRateLimit: Formatter.getInt(json, 'dl_rate_limit'),
      upRateLimit: Formatter.getInt(json, 'up_rate_limit'),
      freeSpaceOnDisk: Formatter.getInt(json, 'free_space_on_disk'),
      globalRatio: Formatter.getDouble(json, 'global_ratio'),
      connectionStatus:
          Formatter.getString(json, 'connection_status', def: 'unknown'),
      dhtNodes: Formatter.getInt(json, 'dht_nodes'),
      queueing: Formatter.getBool(json, 'queueing'),
      useAltSpeedLimits: Formatter.getBool(json, 'use_alt_speed_limits'),
      totalPeerConnections: Formatter.getInt(json, 'total_peer_connections'),
      refreshInterval: Formatter.getInt(json, 'refresh_interval', def: 1500),
      queuedIoJobs: Formatter.getInt(json, 'queued_io_jobs'),
    );
  }

  void updateQbData(Map<String, dynamic> delta, {bool appendHistory = true}) {
    if (delta.isEmpty) return;
    final Map<String, dynamic> d = delta;
    dlInfoSpeed = Formatter.getInt(d, 'dl_info_speed', def: dlInfoSpeed);
    upInfoSpeed = Formatter.getInt(d, 'up_info_speed', def: upInfoSpeed);
    dlInfoData = Formatter.getInt(d, 'dl_info_data', def: dlInfoData);
    upInfoData = Formatter.getInt(d, 'up_info_data', def: upInfoData);
    alltimeDl = Formatter.getInt(d, 'alltime_dl', def: alltimeDl);
    alltimeUl = Formatter.getInt(d, 'alltime_ul', def: alltimeUl);
    dlRateLimit = Formatter.getInt(d, 'dl_rate_limit', def: dlRateLimit);
    upRateLimit = Formatter.getInt(d, 'up_rate_limit', def: upRateLimit);
    freeSpaceOnDisk =
        Formatter.getInt(d, 'free_space_on_disk', def: freeSpaceOnDisk);
    globalRatio = Formatter.getDouble(d, 'global_ratio', def: globalRatio);
    connectionStatus = Formatter.getString(d, 'connection_status',
        def: connectionStatus);
    dhtNodes = Formatter.getInt(d, 'dht_nodes', def: dhtNodes);
    queueing = Formatter.getBool(d, 'queueing', def: queueing);
    useAltSpeedLimits =
        Formatter.getBool(d, 'use_alt_speed_limits', def: useAltSpeedLimits);
    totalPeerConnections = Formatter.getInt(d, 'total_peer_connections',
        def: totalPeerConnections);
    refreshInterval =
        Formatter.getInt(d, 'refresh_interval', def: refreshInterval);
    queuedIoJobs = Formatter.getInt(d, 'queued_io_jobs', def: queuedIoJobs);

    if (appendHistory) {
      _push(dlHistory, dlInfoSpeed);
      _push(upHistory, upInfoSpeed);
    }
  }

  static void _push(List<int> list, int v) {
    list.add(v);
    if (list.length > maxHistory) {
      list.removeRange(0, list.length - maxHistory);
    }
  }

  int get newDlInfoSpeed => dlInfoSpeed;

  int get newUpInfoSpeed => upInfoSpeed;

  int get newDlInfoData => dlInfoData;

  int get newUpInfoData => upInfoData;

  int get newAlltimeDl => alltimeDl;

  int get newAlltimeUl => alltimeUl;

  int get newFreeSpaceOnDisk => freeSpaceOnDisk;

  int get newdlLimit => dlRateLimit;

  int get newupLimit => upRateLimit;

  int get newQueuedIoJobs => queuedIoJobs;

  double get sessionRatio =>
      dlInfoData <= 0 ? 0 : upInfoData / dlInfoData;

  double get alltimeRatio {
    if (globalRatio > 0) return globalRatio;
    return alltimeDl <= 0 ? 0 : alltimeUl / alltimeDl;
  }

  bool get isConnected => connectionStatus.toLowerCase() == 'connected';
}
