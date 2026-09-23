











import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/utils/i18n.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    
    SecurePrefs.useMemoryBackendForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
    AppLog.instance.clear();
  });

  
  group('★ AppLog.op —— 用户操作专用来源', () {
    test('op() 打 OP 标记、级别 INFO，且与 APP/NET/UI 互不相同', () {
      AppLog.instance.op('添加服务器：NAS');
      final LogEntry e = AppLog.instance.entries.first;
      expect(e.source, AppLog.srcOp);
      expect(e.level, 'INFO');
      expect(e.message, '添加服务器：NAS');
      
      final Set<String> all = <String>{
        AppLog.srcApp,
        AppLog.srcNet,
        AppLog.srcUi,
        AppLog.srcOp,
      };
      expect(all.length, 4);
    });

    test('清空后再记一条 —— 日志页不会只剩空白（清空动作本身也留痕）', () {
      AppLog.instance.info('旧日志');
      AppLog.instance.clear();
      expect(AppLog.instance.entries, isEmpty);
      AppLog.instance.op('清空应用日志');
      expect(AppLog.instance.entries.length, 1);
    });
  });

  group('★ 服务器增删改与切换各留一条 OP 日志', () {
    ServerData mk(String id, String name) => ServerData(
          id: id,
          name: name,
          type: 'qbittorrent',
          host: 'example.com',
          port: 8080,
        );

    
    
    
    
    LogEntry lastOp() => AppLog.instance.entries
        .firstWhere((LogEntry e) => e.source == AppLog.srcOp);

    test('add / update / delete / select', () async {
      final ServerController c = Get.put(ServerController());
      await c.loadLocal();

      await c.addServer(mk('a', 'NAS'));
      expect(lastOp().message, '添加服务器：NAS（qbittorrent）');

      await c.updateServer(mk('a', 'NAS-2'));
      expect(lastOp().message, '修改服务器：NAS-2（qbittorrent）');

      
      
      c.select(c.servers.first);
      expect(lastOp().message, '切换当前服务器：NAS-2（qbittorrent）');

      await c.deleteServer('a');
      
      expect(lastOp().message, contains('删除服务器：NAS-2'));
      expect(c.servers, isEmpty);
    });
  });

  
  group('★ 应用显示名 —— 未选过时跟随系统语言，未适配语言回落默认中文', () {
    
    
    
    
    
    setUp(() => L.code.value = '');

    
    
    
    setUp(() => L.useHostLocaleInTest = true);
    tearDown(() => L.useHostLocaleInTest = false);

    testWidgets('en → 英文名；zh / ja 等 → 中文名', (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
      expect(S.appNameLocalized, S.appName);

      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      expect(S.appNameLocalized, S.appNameEn);

      
      
      tester.platformDispatcher.localeTestValue = const Locale('ja', 'JP');
      expect(S.appNameLocalized, S.appName,
          reason: '未适配系统语言时必须使用默认中文');

      tester.platformDispatcher.clearLocaleTestValue();
    });

    test('中英文名与 Android 资源目录的取值一致', () {
      
      
      
      L.code.value = L.zh;
      
      expect(S.appName, '种子管理器');
      expect(S.appNameEn, 'Torrent Manager');
      L.code.value = '';
    });
  });
}
