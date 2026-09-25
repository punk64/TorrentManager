import '../../utils/formatter.dart';

enum TorrentStatusGroup {
  downloading,
  seeding,
  paused,
  queued,
  checking,
  error,
  unknown,
}

class Torrent {
  final String hash;
  final String name;
  final int size;

  final double progress;

  final String state;

  final int dlSpeed;
  final int upSpeed;
  final int numSeeds;
  final int numLeechs;

  final int activePeers;

  final double ratio;

  final String? savePath;
  final String? category;
  final String? tags;

  final String? contentPath;

  final String? magnetUri;

  final String? comment;

  final int uploaded;

  final int downloaded;

  final int dlLimit;

  final int upLimit;

  final int eta;

  final int addedOn;

  final int lastActivity;

  final int completionOn;

  final int seedingTime;

  final int timeActive;

  final int trackerCount;

  final int numComplete;

  final int numIncomplete;

  final double availability;

  final int priority;

  final int amountLeft;

  final int wasted;

  final String? errorMessage;

  final double metadataPercent;

  final int freeSpace;

  final bool? isPrivate;

  final double ratioLimit;

  final int seedingTimeLimit;

  final String rawState;

  final bool? forceStart;

  final bool? sequentialDownload;

  final bool? firstLastPiecePrio;

  final bool? superSeeding;

  final int bandwidthPriority;

  final bool? dlLimited;

  final bool? upLimited;

  final int? trId;

  const Torrent({
    required this.hash,
    required this.name,
    required this.size,
    required this.progress,
    required this.state,
    required this.dlSpeed,
    required this.upSpeed,
    required this.numSeeds,
    required this.numLeechs,
    required this.ratio,
    this.activePeers = -1,
    this.savePath,
    this.category,
    this.tags,
    this.contentPath,
    this.magnetUri,
    this.comment,
    this.uploaded = 0,
    this.downloaded = 0,
    this.dlLimit = 0,
    this.upLimit = 0,
    this.eta = 8640000,
    this.addedOn = 0,
    this.lastActivity = 0,
    this.completionOn = 0,
    this.seedingTime = 0,
    this.timeActive = 0,
    this.trackerCount = 0,
    this.numComplete = 0,
    this.numIncomplete = 0,
    this.availability = 0,
    this.priority = 0,
    this.amountLeft = 0,
    this.wasted = 0,
    this.errorMessage,
    this.metadataPercent = -1,
    this.freeSpace = -1,
    this.isPrivate,
    this.ratioLimit = -2,
    this.seedingTimeLimit = -2,
    this.rawState = '',
    this.forceStart,
    this.sequentialDownload,
    this.firstLastPiecePrio,
    this.superSeeding,
    this.bandwidthPriority = 0,
    this.dlLimited,
    this.upLimited,
    this.trId,
  });

  factory Torrent.fromJson(Map<String, dynamic> json) {
    return Torrent(
      hash: Formatter.getString(json, 'hash'),
      name: Formatter.getString(json, 'name'),
      size: Formatter.getInt(json, 'size'),
      progress: Formatter.getDouble(json, 'progress'),
      state: Formatter.getString(json, 'state', def: 'unknown'),
      dlSpeed: Formatter.getInt(json, 'dlspeed'),
      upSpeed: Formatter.getInt(json, 'upspeed'),
      numSeeds: Formatter.getInt(json, 'num_seeds'),
      numLeechs: Formatter.getInt(json, 'num_leechs'),
      ratio: Formatter.getDouble(json, 'ratio'),
      activePeers: Formatter.getInt(json, 'active_peers', def: -1),
      savePath: Formatter.getStringOrNull(json, 'save_path'),
      category: Formatter.getStringOrNull(json, 'category'),
      tags: Formatter.getStringOrNull(json, 'tags'),
      contentPath: Formatter.getStringOrNull(json, 'content_path'),
      magnetUri: Formatter.getStringOrNull(json, 'magnet_uri'),
      comment: Formatter.getStringOrNull(json, 'comment'),
      uploaded: Formatter.getInt(json, 'uploaded'),
      downloaded: Formatter.getInt(json, 'downloaded'),
      dlLimit: Formatter.getInt(json, 'dl_limit'),
      upLimit: Formatter.getInt(json, 'up_limit'),
      eta: Formatter.getInt(json, 'eta', def: 8640000),
      addedOn: Formatter.getInt(json, 'added_on'),
      lastActivity: Formatter.getInt(json, 'last_activity'),
      completionOn: Formatter.getInt(json, 'completion_on'),
      seedingTime: Formatter.getInt(json, 'seeding_time'),
      timeActive: Formatter.getInt(json, 'time_active'),
      trackerCount: Formatter.getInt(json, 'tracker_count'),
      numComplete: Formatter.getInt(json, 'num_complete'),
      numIncomplete: Formatter.getInt(json, 'num_incomplete'),
      availability: Formatter.getDouble(json, 'availability'),
      priority: Formatter.getInt(json, 'priority'),
      amountLeft: Formatter.getInt(json, 'amount_left'),
      wasted: Formatter.getInt(json, 'total_wasted'),
      errorMessage: Formatter.getStringOrNull(json, 'error_message'),
      metadataPercent: Formatter.getDouble(json, 'metadata_percent', def: -1),
      freeSpace: Formatter.getInt(json, 'free_space', def: -1),
      isPrivate: json['is_private'] is bool ? json['is_private'] as bool : null,
      ratioLimit: Formatter.getDouble(json, 'ratio_limit', def: -2),
      seedingTimeLimit: Formatter.getInt(json, 'seeding_time_limit', def: -2),

      rawState: Formatter.getString(
          json, 'raw_state', def: Formatter.getString(json, 'state', def: '')),
      forceStart: json['force_start'] is bool ? json['force_start'] as bool : null,
      sequentialDownload:
          json['seq_dl'] is bool ? json['seq_dl'] as bool : null,
      firstLastPiecePrio:
          json['f_l_piece_prio'] is bool ? json['f_l_piece_prio'] as bool : null,
      superSeeding:
          json['super_seeding'] is bool ? json['super_seeding'] as bool : null,
      bandwidthPriority: Formatter.getInt(json, 'bandwidth_priority'),
      dlLimited: json['dl_limited'] is bool ? json['dl_limited'] as bool : null,
      upLimited: json['up_limited'] is bool ? json['up_limited'] as bool : null,
    );
  }

  Torrent updateQbData(Map<String, dynamic> delta) {
    if (delta.isEmpty) return this;
    final Map<String, dynamic> base = <String, dynamic>{
      'hash': Formatter.getString(delta, 'hash', def: hash),
      'name': Formatter.getString(delta, 'name', def: name),
      'size': Formatter.getInt(delta, 'size', def: size),
      'progress': Formatter.getDouble(delta, 'progress', def: progress),
      'state': Formatter.getString(delta, 'state', def: state),
      'dlspeed': Formatter.getInt(delta, 'dlspeed', def: dlSpeed),
      'upspeed': Formatter.getInt(delta, 'upspeed', def: upSpeed),
      'num_seeds': Formatter.getInt(delta, 'num_seeds', def: numSeeds),
      'num_leechs': Formatter.getInt(delta, 'num_leechs', def: numLeechs),
      'ratio': Formatter.getDouble(delta, 'ratio', def: ratio),
      'active_peers': Formatter.getInt(delta, 'active_peers', def: activePeers),
      'save_path': Formatter.getStringOrNull(delta, 'save_path') ?? savePath,
      'category': Formatter.getStringOrNull(delta, 'category') ?? category,
      'tags': Formatter.getStringOrNull(delta, 'tags') ?? tags,
      'content_path':
          Formatter.getStringOrNull(delta, 'content_path') ?? contentPath,
      'magnet_uri': Formatter.getStringOrNull(delta, 'magnet_uri') ?? magnetUri,
      'comment': Formatter.getStringOrNull(delta, 'comment') ?? comment,
      'uploaded': Formatter.getInt(delta, 'uploaded', def: uploaded),
      'downloaded': Formatter.getInt(delta, 'downloaded', def: downloaded),
      'dl_limit': Formatter.getInt(delta, 'dl_limit', def: dlLimit),
      'up_limit': Formatter.getInt(delta, 'up_limit', def: upLimit),
      'eta': Formatter.getInt(delta, 'eta', def: eta),
      'added_on': Formatter.getInt(delta, 'added_on', def: addedOn),
      'last_activity':
          Formatter.getInt(delta, 'last_activity', def: lastActivity),
      'completion_on':
          Formatter.getInt(delta, 'completion_on', def: completionOn),
      'seeding_time': Formatter.getInt(delta, 'seeding_time', def: seedingTime),
      'time_active': Formatter.getInt(delta, 'time_active', def: timeActive),
      'tracker_count':
          Formatter.getInt(delta, 'tracker_count', def: trackerCount),
      'num_complete': Formatter.getInt(delta, 'num_complete', def: numComplete),
      'num_incomplete':
          Formatter.getInt(delta, 'num_incomplete', def: numIncomplete),
      'availability':
          Formatter.getDouble(delta, 'availability', def: availability),
      'priority': Formatter.getInt(delta, 'priority', def: priority),
      'amount_left': Formatter.getInt(delta, 'amount_left', def: amountLeft),
      'total_wasted': Formatter.getInt(delta, 'total_wasted', def: wasted),
      'error_message':
          Formatter.getStringOrNull(delta, 'error_message') ?? errorMessage,
      'metadata_percent': Formatter.getDouble(
          delta, 'metadata_percent', def: metadataPercent),
      'free_space': Formatter.getInt(delta, 'free_space', def: freeSpace),
      'is_private':
          delta['is_private'] is bool ? delta['is_private'] as bool : isPrivate,
      'ratio_limit':
          Formatter.getDouble(delta, 'ratio_limit', def: ratioLimit),
      'seeding_time_limit':
          Formatter.getInt(delta, 'seeding_time_limit', def: seedingTimeLimit),

      'force_start': delta['force_start'] is bool
          ? delta['force_start'] as bool
          : forceStart,
      'seq_dl':
          delta['seq_dl'] is bool ? delta['seq_dl'] as bool : sequentialDownload,
      'f_l_piece_prio': delta['f_l_piece_prio'] is bool
          ? delta['f_l_piece_prio'] as bool
          : firstLastPiecePrio,
      'super_seeding': delta['super_seeding'] is bool
          ? delta['super_seeding'] as bool
          : superSeeding,
    };
    return Torrent.fromJson(base).copyWithTrId(trId);
  }

  Torrent copyWithTrId(int? id) => Torrent(
        hash: hash,
        name: name,
        size: size,
        progress: progress,
        state: state,
        dlSpeed: dlSpeed,
        upSpeed: upSpeed,
        numSeeds: numSeeds,
        numLeechs: numLeechs,
        ratio: ratio,
        activePeers: activePeers,
        savePath: savePath,
        category: category,
        tags: tags,
        contentPath: contentPath,
        magnetUri: magnetUri,
        comment: comment,
        uploaded: uploaded,
        downloaded: downloaded,
        dlLimit: dlLimit,
        upLimit: upLimit,
        eta: eta,
        addedOn: addedOn,
        lastActivity: lastActivity,
        completionOn: completionOn,
        seedingTime: seedingTime,
        timeActive: timeActive,
        trackerCount: trackerCount,
        numComplete: numComplete,
        numIncomplete: numIncomplete,
        availability: availability,
        priority: priority,
        amountLeft: amountLeft,
        wasted: wasted,
        errorMessage: errorMessage,
        metadataPercent: metadataPercent,
        freeSpace: freeSpace,
        isPrivate: isPrivate,
        ratioLimit: ratioLimit,
        seedingTimeLimit: seedingTimeLimit,
        rawState: rawState,
        forceStart: forceStart,
        sequentialDownload: sequentialDownload,
        firstLastPiecePrio: firstLastPiecePrio,
        superSeeding: superSeeding,
        bandwidthPriority: bandwidthPriority,
        dlLimited: dlLimited,
        upLimited: upLimited,
        trId: id,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hash': hash,
        'name': name,
        'size': size,
        'progress': progress,
        'state': state,
        'dlspeed': dlSpeed,
        'upspeed': upSpeed,
        'num_seeds': numSeeds,
        'num_leechs': numLeechs,
        'ratio': ratio,
        'active_peers': activePeers,
        'save_path': savePath,
        'category': category,
        'tags': tags,
        'content_path': contentPath,
        'magnet_uri': magnetUri,
        'comment': comment,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'dl_limit': dlLimit,
        'up_limit': upLimit,
        'eta': eta,
        'added_on': addedOn,
        'last_activity': lastActivity,
        'completion_on': completionOn,
        'seeding_time': seedingTime,
        'time_active': timeActive,
        'tracker_count': trackerCount,
        'num_complete': numComplete,
        'num_incomplete': numIncomplete,
        'availability': availability,
        'priority': priority,
        'amount_left': amountLeft,
        'total_wasted': wasted,
        'error_message': errorMessage,
        'metadata_percent': metadataPercent,
        'free_space': freeSpace,
        'is_private': isPrivate,
        'ratio_limit': ratioLimit,
        'seeding_time_limit': seedingTimeLimit,
        'raw_state': rawState,
        'force_start': forceStart,
        'seq_dl': sequentialDownload,
        'f_l_piece_prio': firstLastPiecePrio,
        'super_seeding': superSeeding,
        'bandwidth_priority': bandwidthPriority,
        'dl_limited': dlLimited,
        'up_limited': upLimited,
      };

  String get newState => state;

  bool get isPause {
    final String s = state.toLowerCase();
    return s.contains('paused') ||
        s.contains('stop') ||
        s == 'stopped' ||
        s.contains('paus');
  }

  int get newRelativeSize => (size * progress).round();

  int get newUploaded => uploaded;

  int get newDlLimit => dlLimit;

  int get newDownSpeed => dlSpeed;

  int get newUpLimit => upLimit;

  int get newUpspeed => upSpeed;

  int get newEta => eta >= 8640000 ? 0 : eta;

  int get newAddedOn => addedOn;

  int get newLastActivity => lastActivity;

  int get newTrackerCount => trackerCount;

  int get newSize => size;

  int get newSeedingTime => seedingTime;

  int get newTimeActive => timeActive;

  int get newCompletionOn => completionOn;

  bool get isDownloading {
    if (isPause) return false;
    final String s = state.toLowerCase();
    return s.contains('dl') ||
        s.contains('download') ||
        s.contains('meta') ||
        s.contains('forceddl');
  }

  bool get isSeeding {
    if (isPause) return false;
    final String s = state.toLowerCase();
    return s.contains('up') ||
        s.contains('seed') ||
        s.contains('upload') ||
        s.contains('forcedup');
  }

  bool get isCompleted => progress >= 1.0;

  bool get isPausedDL => isPause && !isCompleted;

  bool get isPausedUP => isPause && isCompleted;

  bool get isChecking => state.toLowerCase().contains('check');

  bool get isError {
    final String s = state.toLowerCase();
    return s.contains('error') || s.contains('missing');
  }

  bool get isStalled => state.toLowerCase().contains('stall');

  TorrentStatusGroup get statusGroup {
    final String s = state.toLowerCase();
    if (isError) return TorrentStatusGroup.error;
    if (s.contains('check')) return TorrentStatusGroup.checking;
    if (s.contains('paus') || s.contains('stop')) return TorrentStatusGroup.paused;
    if (s.contains('queued')) return TorrentStatusGroup.queued;

    if (s.contains('stalleddl') ||
        s.contains('forceddl') ||
        s.contains('download') ||
        s.contains('dl')) {
      return TorrentStatusGroup.downloading;
    }
    if (s.contains('stalledup') ||
        s.contains('forcedup') ||
        s.contains('seed') ||
        s.contains('upload') ||
        s.contains('up')) {
      return TorrentStatusGroup.seeding;
    }
    return TorrentStatusGroup.unknown;
  }

  bool get dlLimitedEnabled => dlLimited ?? dlLimit > 0;

  bool get upLimitedEnabled => upLimited ?? upLimit > 0;

  int get transferPeers {
    if (activePeers >= 0) return activePeers;
    return (dlSpeed > 0 || upSpeed > 0) ? numSeeds + numLeechs : 0;
  }

  bool get isUploading => upSpeed > 0;

  bool get isActive => dlSpeed > 0 || upSpeed > 0;

  List<String> get tagList => (tags ?? '')
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();

  String get categoryName =>
      (category == null || category!.isEmpty) ? '未分类' : category!;

  String get pathName =>
      (savePath == null || savePath!.isEmpty) ? '未指定' : savePath!;

  String get site =>
      Formatter.trackerHost(comment) ?? Formatter.trackerHost(magnetUri) ?? '';
}

class TorrentStatusCounts {
  const TorrentStatusCounts({
    required this.downloading,
    required this.seeding,
    required this.paused,
    required this.checking,
    required this.error,
    required this.other,
  });

  factory TorrentStatusCounts.of(Iterable<Torrent> list) {
    int dl = 0;
    int up = 0;
    int paused = 0;
    int checking = 0;
    int error = 0;
    int other = 0;
    for (final Torrent t in list) {
      if (t.isError) {
        error++;
      } else if (t.isChecking) {
        checking++;
      } else if (t.isPause) {
        paused++;
      } else if (t.isDownloading) {
        dl++;
      } else if (t.isSeeding || t.isUploading) {
        up++;
      } else {
        other++;
      }
    }
    return TorrentStatusCounts(
      downloading: dl,
      seeding: up,
      paused: paused,
      checking: checking,
      error: error,
      other: other,
    );
  }

  const TorrentStatusCounts.empty()
      : downloading = 0,
        seeding = 0,
        paused = 0,
        checking = 0,
        error = 0,
        other = 0;

  final int downloading;
  final int seeding;
  final int paused;
  final int checking;
  final int error;

  final int other;

  int get total =>
      downloading + seeding + paused + checking + error + other;
}

class TransferTotals {
  const TransferTotals({
    this.peers = 0,
    this.uploadedBytes = 0,
    this.downloadedBytes = 0,
  });

  factory TransferTotals.of(Iterable<Torrent> list) {
    int peers = 0;
    int up = 0;
    int dl = 0;
    for (final Torrent t in list) {
      peers += t.transferPeers;
      up += t.uploaded < 0 ? 0 : t.uploaded;
      dl += t.downloaded < 0 ? 0 : t.downloaded;
    }
    return TransferTotals(peers: peers, uploadedBytes: up, downloadedBytes: dl);
  }

  final int peers;
  final int uploadedBytes;
  final int downloadedBytes;

  int get movedBytes => uploadedBytes + downloadedBytes;
}

class TotalsSnapshot {
  const TotalsSnapshot({
    required this.dlSpeed,
    required this.upSpeed,
    required this.counts,
    required this.totals,
    required this.serversOnline,
    required this.serversTotal,
    this.available = true,
  });

  factory TotalsSnapshot.empty({required int serversTotal}) => TotalsSnapshot(
        dlSpeed: 0,
        upSpeed: 0,
        counts: const TorrentStatusCounts.empty(),
        totals: const TransferTotals(),
        serversOnline: 0,
        serversTotal: serversTotal,
        available: false,
      );

  final int dlSpeed;
  final int upSpeed;
  final TorrentStatusCounts counts;
  final TransferTotals totals;
  final int serversOnline;
  final int serversTotal;

  final bool available;

  TotalsSnapshot copyWith({
    int? serversOnline,
    int? serversTotal,
    bool? available,
  }) =>
      TotalsSnapshot(
        dlSpeed: dlSpeed,
        upSpeed: upSpeed,
        counts: counts,
        totals: totals,
        serversOnline: serversOnline ?? this.serversOnline,
        serversTotal: serversTotal ?? this.serversTotal,
        available: available ?? this.available,
      );
}
