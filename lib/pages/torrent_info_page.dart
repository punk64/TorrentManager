import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/file_export.dart';
import '../utils/formatter.dart';
import '../widgets/ui_dialogs.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';
import '../widgets/auto_refresh.dart';
import 'torrent_info_files_page.dart';
import 'torrent_info_overview_page.dart';
import 'torrent_info_peers_page.dart';
import 'torrent_info_trackers_page.dart';
import '../app/adaptive.dart';

class TorrentInfoPage extends StatelessWidget {
  const TorrentInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TorrentController ctrl = Get.find<TorrentController>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L.t('种子详情'), style: TextStyle(fontSize: af(context, 15))),
          actions: <Widget>[

            Obx(() {
              if (!ctrl.capabilities.exportTorrent) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.download, size: AppTheme.iconSize),
                tooltip: S.btExportTorrent,
                onPressed: () async {
                  final ServerController sc = Get.find<ServerController>();
                  final s = sc.current.value;
                  final t = ctrl.current.value;
                  if (t == null) {
                    UiDialogs.showToast(S.pleaseSelectTorrent, isError: true);
                    return;
                  }
                  if (s == null) {
                    UiDialogs.showToast(S.noServer, isError: true);
                    return;
                  }
                  try {
                    final List<int> bytes = await sc.qb.exportTorrent(t.hash);
                    if (bytes.isEmpty) {
                      UiDialogs.showToast(S.btExportFail, isError: true);
                      return;
                    }

                    final String? saved = await FileExport.saveBytesAs(
                      fileName: '${t.name}.torrent',
                      bytes: Uint8List.fromList(bytes),
                      dialogTitle: S.btExportTorrent,
                    );
                    if (saved == null) return;
                    UiDialogs.showToast('${S.btExportOk} $saved');
                  } catch (e) {
                    UiDialogs.showToast(
                        '${S.btExportFailPrefix}${Formatter.safeErr(e)}',
                        isError: true);
                  }
                },
              );
            }),
            IconButton(
              icon: const Icon(Icons.refresh, size: AppTheme.iconSize),
              onPressed: ctrl.loadDetailData,
            ),
          ],
          bottom: TabBar(
            labelStyle: TextStyle(fontSize: af(context, 12)),

            tabs: <Widget>[
              Tab(text: L.t('概览'), height: af(context, 38)),
              Tab(text: 'Tracker', height: af(context, 38)),
              Tab(text: 'Peers', height: af(context, 38)),
              Tab(text: L.t('文件'), height: af(context, 38)),
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
