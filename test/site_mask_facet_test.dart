








import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  
  
  
  
  setUp(() {
    
    
    
    
    SecurePrefs.useMemoryBackendForTest();
  });


  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  group('Formatter.maskSite —— 部分遮蔽', () {
    test('常规域名：主域**首字母** + 顶级后缀，子域丢掉', () {
      expect(Formatter.maskSite('example.com'), 'e***.com');
      expect(Formatter.maskSite('bt.byr.cn'), 'b***.cn',
          reason: '多级域名只保留主域，子域 bt. 丢掉');
      expect(Formatter.maskSite('tracker.example.org'), 'e***.org',
          reason: '子域 tracker. 不参与显示（否则又长又没意义）');
      expect(Formatter.maskSite('ab.org'), '***.org',
          reason: '主域只有 2 字符 → 整体遮掉');
    });

    test('IP 地址：主域段太短 → 整体遮掉', () {
      expect(Formatter.maskSite('1.2.3.4'), '***.4');
    });

    test('无后缀：过短全遮，否则留首尾各 1 个字符', () {
      expect(Formatter.maskSite('localhost'), 'l***t');
      expect(Formatter.maskSite('abc'), '***');
      expect(Formatter.maskSite('ab'), '***');
    });

    test('空串原样返回（列表里不会显示空站点）', () {
      expect(Formatter.maskSite(''), '');
      expect(Formatter.maskSite('   '), '');
    });

    test('打码后仍能看出后缀 —— 这是"部分"遮蔽的意义', () {
      for (final String h in <String>[
        'example.com',
        'aaaaaaaaa.net',
        'x.io',
        'tracker.example.org',
      ]) {
        final String masked = Formatter.maskSite(h);
        final String tail = '.${h.split('.').last}';
        expect(masked.endsWith(tail), isTrue,
            reason: '$h 打码后应保留后缀 $tail，实际 $masked');
        expect(masked.contains('***'), isTrue,
            reason: '$h 打码后应出现掩码 $masked');
      }
    });
  });

  group('日志隐私模式：maskLogText', () {
    test('IPv4（含端口）整体打码', () {
      expect(Formatter.maskLogText('连接 192.168.1.100 成功'),
          '连接 ***.***.***.*** 成功');
      expect(Formatter.maskLogText('http://10.0.0.7:8080/api/v2/app/version'),
          'http://***.***.***.***:***/api/v2/app/version');
    });

    test('域名按站点同款规则打码（首字母 + 根域名，丢子域）', () {
      expect(Formatter.maskLogText('tracker.example.org announce ok'),
          'e***.org announce ok');
      expect(Formatter.maskLogText('连到 bt.byr.cn:6969'),
          '连到 b***.cn:***');
    });

    test('文件名不被误判成域名', () {
      expect(Formatter.maskLogText('正在下载 movie.mp4'),
          '正在下载 movie.mp4');
      expect(Formatter.maskLogText('写入 /downloads/data.log 失败'),
          '写入 /downloads/data.log 失败');
      
      expect(Formatter.maskLogText('video.1080p'), 'video.1080p');
    });

    test('空串与无主机信息的文本原样返回', () {
      expect(Formatter.maskLogText(''), '');
      expect(Formatter.maskLogText('开始监听'), '开始监听');
    });

    test('性能：长日志行不出现明显的指数级耗时（线性扫描 + 预编译正则）', () {
      
      final String line =
          List<String>.generate(200, (int i) => 'host$i.example.com:8080 ')
              .join();
      final Stopwatch sw = Stopwatch()..start();
      final String out = Formatter.maskLogText(line);
      sw.stop();
      expect(out.contains('example.com'), isFalse, reason: '域名主体应被打码');
      expect(out.contains('***'), isTrue);
      
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '2000 字符 / 200 个域名应远快于 500ms，实测 ${sw.elapsedMilliseconds}ms');
    });
  });

  group('站点打码开关（2026-09-19 从 SettingsController 搬到 TorrentController）', () {
    
    TorrentController makeTc() {
      Get.put(ServerController());
      return Get.put(TorrentController());
    }

    test('★ 默认开启（2026-09-20 起隐私优先），且可持久化', () async {
      final TorrentController tc = makeTc();
      expect(tc.siteMasked.value, isTrue,
          reason: '★ 用户要求「所有隐私开关默认打开」：默认就不显示真实站点名');

      
      await tc.loadSiteMasked();
      expect(tc.siteMasked.value, isTrue, reason: '★ 缺省值同样必须打码');

      
      tc.setSiteMasked(false);
      expect(tc.siteMasked.value, isFalse);

      
      Get.reset();
      final TorrentController tc2 = makeTc();
      await tc2.loadSiteMasked();
      expect(tc2.siteMasked.value, isFalse, reason: '★ 关掉的选择要能读回来');
    });
  });

  group('单维度清除筛选', () {
    
    
    TorrentController makeCtrl() {
      Get.put(ServerController());
      return Get.put(TorrentController());
    }

    test('clearFacet 只清指定维度，其余维度保留', () {
      final TorrentController c = makeCtrl();
      c.toggleFacet(FilterDim.category, '动画');
      c.toggleFacet(FilterDim.tags, '合集');
      c.toggleFacet(FilterDim.site, 'example.com');

      expect(c.hasFacet(FilterDim.category), isTrue);
      c.clearFacet(FilterDim.category);

      expect(c.hasFacet(FilterDim.category), isFalse, reason: '分类应被清空');
      expect(c.hasFacet(FilterDim.tags), isTrue, reason: '标签不该被连带清掉');
      expect(c.hasFacet(FilterDim.site), isTrue, reason: '站点不该被连带清掉');
      expect(c.hasFacets, isTrue, reason: '仍有其它维度在筛，所以还有筛选');
    });

    test('clearFacets 才是清空全部四维', () {
      final TorrentController c = makeCtrl();
      c.toggleFacet(FilterDim.category, '动画');
      c.toggleFacet(FilterDim.tags, '合集');
      c.toggleFacet(FilterDim.path, '/downloads');
      c.toggleFacet(FilterDim.site, 'example.com');
      expect(c.hasFacets, isTrue);

      c.clearFacets();
      expect(c.hasFacets, isFalse);
      for (final FilterDim d in FilterDim.values) {
        expect(c.hasFacet(d), isFalse);
      }
    });
  });
}
