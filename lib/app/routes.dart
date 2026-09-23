import 'package:get/get.dart';

import 'page_style.dart';
import 'style_keys.dart';

import '../pages/log_page.dart';
import '../pages/log_qb_page.dart';
import '../pages/server_list_page.dart';
import '../pages/server_setting_page.dart';
import '../pages/share_page.dart';
import '../pages/theme_page.dart';
import '../pages/torrent_add_page.dart';
import '../pages/torrent_info_page.dart';
import '../pages/torrent_list_page.dart';




















class Routes {
  static const servers = '/servers';
  static const torrents = '/torrents';
  
  
  
  
  
  static const theme = '/theme';
  static const share = '/share';
  static const log = '/log';
  static const logQb = '/logQb';
  static const serverSetting = '/serverSetting';
  static const torrentAdd = '/torrentAdd';
  static const torrentInfo = '/torrentInfo';
}

class AppPages {
  static final pages = <GetPage<dynamic>>[
    
    
    GetPage(
      name: Routes.servers,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.serverList,
        applyCardBackground: true,
        child: ServerListPage(),
      ),
    ),
    GetPage(
      name: Routes.torrents,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.torrentList,
        applyCardBackground: true,
        child: TorrentListPage(),
      ),
    ),
    
    
    
    
    
    
    GetPage(
      name: Routes.theme,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.settings,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: ThemePage(),
      ),
    ),
    GetPage(
      name: Routes.share,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.settings,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: SharePage(),
      ),
    ),
    GetPage(
      name: Routes.log,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.log,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: LogPage(),
      ),
    ),
    GetPage(
      name: Routes.logQb,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.logQb,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: LogQbPage(),
      ),
    ),
    GetPage(
      name: Routes.serverSetting,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.settings,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: ServerSettingPage(),
      ),
    ),
    GetPage(
      name: Routes.torrentAdd,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.torrentList,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: TorrentAddPage(),
      ),
    ),
    GetPage(
      name: Routes.torrentInfo,
      page: () => const AppPageTheme(
          pageLevel: true,
        page: AppPageKey.torrentDetail,
        applyCardBackground: true,
        
        fixedScrim: AppPageBackground.fixedScrimValue,
        child: TorrentInfoPage(),
      ),
    ),
  ];
}
