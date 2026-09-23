import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import 'torrent_info_files_page.dart';
import 'torrent_info_overview_page.dart';
import 'torrent_info_peers_page.dart';
import 'torrent_info_trackers_page.dart';

class TorrentInfoPage extends StatelessWidget {
  const TorrentInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TorrentController ctrl = Get.find<TorrentController>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('种子详情', style: TextStyle(fontSize: 15)),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.download, size: AppTheme.iconSize),
              tooltip: S.btExportTorrent,
              onPressed: () async {
                final ServerController sc = Get.find<ServerController>();
                final s = sc.current.value;
                final t = ctrl.current.value;
                if (t == null) {
                  Formatter.showToast(S.pleaseSelectTorrent, isError: true);
                  return;
                }
                if (s == null) {
                  Formatter.showToast(S.noServer, isError: true);
                  return;
                }

                if (!s.isQbittorrent) {
                  Formatter.showToast(S.btExportTrUnsupported, isError: true);
                  return;
                }
                try {
                  final List<int> bytes = await sc.qb.exportTorrent(t.hash);
                  if (bytes.isEmpty) {
                    Formatter.showToast(S.btExportFail, isError: true);
                    return;
                  }
                  final Directory dir =
                      await getApplicationDocumentsDirectory();

                  final File f = File(
                      '${dir.path}/${Formatter.safeFileName(t.name)}.torrent');
                  await f.writeAsBytes(bytes);
                  Formatter.showToast('${S.btExportOk} ${f.uri.pathSegments.last}');
                } catch (e) {
                  Formatter.showToast('${S.btExportFailPrefix}${Formatter.safeErr(e)}',
                      isError: true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: AppTheme.iconSize),
              onPressed: ctrl.loadDetailData,
            ),
          ],
          bottom: const TabBar(
            labelStyle: TextStyle(fontSize: 12),

            tabs: <Widget>[
              Tab(text: '概览', height: 38),
              Tab(text: 'Tracker', height: 38),
              Tab(text: 'Peers', height: 38),
              Tab(text: '文件', height: 38),
            ],
          ),
        ),
        body: AutoRefresh(
          onTick: ctrl.loadDetailData,
          child: const TabBarView(
            children: <Widget>[
              TorrentInfoOverviewPage(),
              TorrentInfoTrackersPage(),
              TorrentInfoPeersPage(),
              TorrentInfoFilesPage(),
            ],
          ),
        ),
      ),
    );
  }
}
