import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../controllers/torrent_controller.dart';
import '../utils/file_export.dart';
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
            // ★ 导出按钮按**能力**显隐：
            //   TR 根本没有导出接口（D4 ⇒ 隐藏，不给点了才报错的按钮）；
            //   qB 要 4.5+（WebAPI 2.8.14）才有 `torrents/export`（V3 ⇒ 按版本隐藏）。
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
                    Formatter.showToast(S.pleaseSelectTorrent, isError: true);
                    return;
                  }
                  if (s == null) {
                    Formatter.showToast(S.noServer, isError: true);
                    return;
                  }
                  try {
                    final List<int> bytes = await sc.qb.exportTorrent(t.hash);
                    if (bytes.isEmpty) {
                      Formatter.showToast(S.btExportFail, isError: true);
                      return;
                    }
                    // ★ 走系统「另存为」让用户自己选位置：
                    //   直接写 app 私有目录在 Android 11+ 的文件管理器里看不到。
                    final String? saved = await FileExport.saveBytesAs(
                      fileName: '${t.name}.torrent',
                      bytes: Uint8List.fromList(bytes),
                      dialogTitle: S.btExportTorrent,
                    );
                    if (saved == null) return; // 用户取消
                    Formatter.showToast('${S.btExportOk} $saved');
                  } catch (e) {
                    Formatter.showToast(
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
