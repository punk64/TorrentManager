











import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/local/secure_prefs.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';

Torrent _t(String hash) => Torrent(
      hash: hash,
      name: '种子 $hash',
      size: 100,
      progress: 0.5,
      state: 'seeding',
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
    );

ServerData srv(String id) => ServerData(
      id: id,
      name: '服务器 $id',
      type: 'qbittorrent',
      host: '192.168.1.10',
      port: 8080,
      username: 'admin',
      password: 'pw',
    );






class HangAdapter implements HttpClientAdapter {
  final List<String> calls = <String>[];

  
  final Completer<void> gate = Completer<void>();

  Dio dio() => Dio(BaseOptions(
        baseUrl: 'http://192.168.1.10:8080',
        validateStatus: (int? s) => s != null && s < 500,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ))
        ..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    await gate.future;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecurePrefs.useMemoryBackendForTest);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall call) async => null);
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  

  test('第 53 轮 A · 超过 5 台时淘汰最久未用的那台', () {
    final ServerController sc = ServerController(qb: QbMethod());
    for (int i = 1; i <= 5; i++) {
      sc.cacheTorrents('s$i', <Torrent>[_t('h$i')]);
    }
    expect(sc.torrentCache.length, ServerController.kCacheMaxServers);

    sc.cacheTorrents('s6', <Torrent>[_t('h6')]);

    expect(sc.torrentCache.length, ServerController.kCacheMaxServers,
        reason: '★ 台数必须有上限：几台大库同时缓存会把内存吃满');
    expect(sc.hasAnyCache('s1'), isFalse, reason: '★ s1 最久未用 → 被淘汰');
    expect(sc.hasAnyCache('s6'), isTrue, reason: '新写入的那台必须在');
  });

  test('第 53 轮 A2 · 淘汰按「最近使用」而不是「最早写入」', () {
    final ServerController sc = ServerController(qb: QbMethod());
    for (int i = 1; i <= 5; i++) {
      sc.cacheTorrents('s$i', <Torrent>[_t('h$i')]);
    }
    
    sc.torrentsOf('s1');

    sc.cacheTorrents('s6', <Torrent>[_t('h6')]);

    expect(sc.hasAnyCache('s1'), isTrue,
        reason: '★ 刚被读过 → 不该被淘汰（用户反复看的那台要留住）');
    expect(sc.hasAnyCache('s2'), isFalse, reason: '★ s2 才是最久未用的');
  });

  test('第 53 轮 A3 · 当前正在看的服务器豁免淘汰', () {
    final ServerController sc = ServerController(qb: QbMethod());
    final ServerData cur = srv('cur');
    sc.servers.assignAll(<ServerData>[cur]);
    sc.current.value = cur;
    sc.cacheTorrents('cur', <Torrent>[_t('h')]);
    for (int i = 1; i <= 5; i++) {
      sc.cacheTorrents('s$i', <Torrent>[_t('h$i')]);
    }

    expect(sc.hasAnyCache('cur'), isTrue,
        reason: '★ 当前服务器即使最久未用也不淘汰 —— 否则用户眼前的数据会被抽走');
    expect(sc.hasAnyCache('s1'), isFalse, reason: '淘汰的是别人');
  });

  

  test('第 53 轮 B · lite 缓存只够算卡片统计，不能给列表页用', () {
    final ServerController sc = ServerController(qb: QbMethod());
    
    sc.cacheTorrents('tr-1', <Torrent>[_t('h1')], lite: true);

    expect(sc.hasAnyCache('tr-1'), isTrue, reason: '卡片统计用得上');
    expect(sc.hasFullCache('tr-1'), isFalse,
        reason: '★ lite 缺字段 → 不能当列表页的数据源，否则站点/tracker 会是空的');

    sc.cacheTorrents('tr-1', <Torrent>[_t('h1')]);
    expect(sc.hasFullCache('tr-1'), isTrue, reason: '全量写入后升级为完整缓存');
  });

  

  test('第 53 轮 C · 网络还挂着时，列表已用缓存渲染出来', () async {
    final HangAdapter ad = HangAdapter();
    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: ad.dio())));
    final ServerData s = srv('qb-1');
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;
    sc.cacheTorrents(s.id, <Torrent>[_t('h1'), _t('h2'), _t('h3')]);

    final TorrentController ctrl = Get.put(TorrentController());
    expect(ctrl.items, isEmpty, reason: '前置：还没进列表');

    unawaited(ctrl.refresh());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(ctrl.items.length, 3,
        reason: '★ 真实数据还在半空，列表已用缓存渲染 —— 这就是"秒进"的来源');
    expect(ad.calls.isNotEmpty, isTrue,
        reason: '★ 缓存渲染**不替代**真实刷新：请求必须照发，不能因为有了缓存就不刷新');
  });

  test('第 53 轮 C2 · 列表已有数据时不拿缓存覆盖', () async {
    final HangAdapter ad = HangAdapter();
    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: ad.dio())));
    final ServerData s = srv('qb-1');
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;
    sc.cacheTorrents(s.id, <Torrent>[_t('h1'), _t('h2')]);

    final TorrentController ctrl = Get.put(TorrentController());
    
    ctrl.debugSetItems(<Torrent>[_t('mine')]);

    unawaited(ctrl.refresh());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(ctrl.items.length, 1, reason: '★ 已有数据时**不**被缓存覆盖');
    expect(ctrl.items.first.hash, 'mine');
  });

  test('第 53 轮 D · 缓存渲染给的是副本，列表改动不污染缓存', () async {
    final HangAdapter ad = HangAdapter();
    final ServerController sc =
        Get.put(ServerController(qb: QbMethod(dio: ad.dio())));
    final ServerData s = srv('qb-1');
    sc.servers.assignAll(<ServerData>[s]);
    sc.current.value = s;
    sc.cacheTorrents(s.id, <Torrent>[_t('h1'), _t('h2'), _t('h3')]);

    final TorrentController ctrl = Get.put(TorrentController());
    unawaited(ctrl.refresh());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    ctrl.items.removeAt(0); 

    expect(sc.torrentsOf(s.id).length, 3,
        reason: '★ 列表与缓存必须是两份 —— 否则列表页的删除会直接改到卡片的数据源');
  });
}
