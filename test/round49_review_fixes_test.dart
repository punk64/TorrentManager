












import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/controllers/torrent_controller.dart';
import 'package:torrent_manager/data/dio/log_interceptor.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/models/torrent.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/utils/net_error.dart';
import 'package:torrent_manager/utils/update_check.dart';

Torrent _mk({
  required String hash,
  int size = 100,
  String state = 'downloading',
  String? savePath,
}) =>
    Torrent(
      hash: hash,
      name: '种子$hash',
      size: size,
      progress: 0.5,
      state: state,
      dlSpeed: 0,
      upSpeed: 0,
      numSeeds: 0,
      numLeechs: 0,
      ratio: 0,
      savePath: savePath,
    );

void main() {
  
  group('L5 辅种判定：size=0 不参与', () {
    test('★ 两条都还没取到元数据（size=0）→ 互不认作辅种', () {
      final Torrent main = _mk(hash: 'h1', size: 0, savePath: '/dl');
      final Torrent pending = _mk(hash: 'h2', size: 0, savePath: '/dl');
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[main, pending],
        chosen: <Torrent>[main],
        deleteSub: true,
      );
      expect(p.subs, isEmpty,
          reason: 'size=0 是"元数据还没到"，不是"体积相同" —— '
              '据此删任务是删掉一批不相干的下载');
    });

    test('回归保护：体积相同 + 同目录 → 仍然是辅种', () {
      final Torrent main = _mk(hash: 'h1', size: 500, savePath: '/dl/show');
      final Torrent sub = _mk(hash: 'h2', size: 500, savePath: '/dl/show/');
      final DeletePlan p = TorrentController.planDelete(
        all: <Torrent>[main, sub],
        chosen: <Torrent>[main],
        deleteSub: true,
      );
      expect(p.subs.map((Torrent t) => t.hash), <String>['h2']);
    });
  });

  
  group('L8 configProblemOf 校验服务器类型', () {
    test('★ 非法 type → 判为「配置不完整」（而不是让它永久转圈）', () {
      final ServerData s = ServerData(
        id: 'x',
        name: 'x',
        type: 'utorrent',
        host: '1.2.3.4',
        port: 8080,
      );
      expect(ServerController.configProblemOf(s),
          ConnErrorKind.missingConfig);
    });

    test('qBittorrent / Transmission → 放行', () {
      ServerData mk(String type) => ServerData(
            id: 'x',
            name: 'x',
            type: type,
            host: '1.2.3.4',
            port: 8080,
          );
      expect(ServerController.configProblemOf(mk('qbittorrent')), isNull);
      expect(ServerController.configProblemOf(mk('transmission')), isNull);
    });
  });

  
  group('L1 TR：探测期间路由被切换 ≠ 登录失败', () {
    ServerData pub() => ServerData(
          id: 'tr',
          name: 'TR',
          type: 'transmission',
          host: 'tr.example.com',
          port: 9091,
          username: 'admin',
          password: 'pw',
        );

    ServerData lan() => ServerData(
          id: 'tr',
          name: 'TR',
          type: 'transmission',
          host: '192.168.1.5',
          port: 9091,
          username: 'admin',
          password: 'pw',
          lanHost: '192.168.1.5',
          lanPort: 9091,
        );

    test('★ 改用新路由重登成功 → 结果是 ok（不是「已放弃本次重登」）', () async {
      TrMethod? tr;
      int calls = 0;
      final Dio dio = Dio(BaseOptions(baseUrl: pub().baseUrl));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          calls++;
          if (calls == 1) {
            
            
            tr!.setServer(lan());
            h.reject(DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: o,
                statusCode: 401,
              ),
            ));
            return;
          }
          h.resolve(Response<dynamic>(
            requestOptions: o,
            statusCode: 200,
            data: <String, dynamic>{
              'result': 'success',
              'arguments': <String, dynamic>{},
            },
          ));
        },
      ));
      tr = TrMethod(dio: dio);

      final TrLoginResult r = await tr.checkTrServerCookie(pub());
      expect(r.ok, isTrue,
          reason: '换路由后应当在新路由上重登一次 —— 直接判失败会让上层'
              '按 authFailed 挂起该服务器（TR 卡片永久显示登录失败）');
    });

    test('第二次仍失败（路由又变了）→ 标记为 routeSwitch，不冒充「密码错」',
        () async {
      TrMethod? tr;
      int calls = 0;
      final Dio dio = Dio(BaseOptions(baseUrl: pub().baseUrl));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          calls++;
          
          
          tr!.setServer(calls.isEven ? pub() : lan());
          h.reject(DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(requestOptions: o, statusCode: 401),
          ));
        },
      ));
      tr = TrMethod(dio: dio);

      final TrLoginResult r = await tr.checkTrServerCookie(pub());
      expect(r.ok, isFalse);
      expect(r.routeChanged, isTrue,
          reason: '这一类失败上层必须**跳过本轮**（等下一轮按新路由重试），'
              '绝不能当 authFailed 挂起');
      expect(r.missingCreds, isFalse);
    });
  });

  
  group('S5 4xx/5xx 响应体入日志前先脱敏', () {
    test('★ Basic 鉴权头被抹掉（base64 等于明文口令）', () {
      final String b = AppLogInterceptor.bodyBrief(
          'Unauthorized: Authorization: Basic YWRtaW46cGFzc3dvcmQ=');
      expect(b, isNot(contains('YWRtaW46cGFzc3dvcmQ')));
      expect(b, contains('***'));
    });

    test('★ URL 里的 userinfo 被抹掉', () {
      final String b = AppLogInterceptor.bodyBrief(
          'proxy error: http://admin:secret@nas.example.com:8080/x');
      expect(b, isNot(contains('secret')));
      expect(b, contains('***:***@'));
    });

    test('普通原因文本照旧保留（脱敏不能把有用的诊断吃掉）', () {
      final String b = AppLogInterceptor.bodyBrief('Invalid hash.');
      expect(b, contains('Invalid hash.'));
    });
  });

  
  group('S6 更新检查只接受 https', () {
    test('★ http 地址直接拒绝，一个请求都不发', () async {
      bool called = false;
      final UpdateChecker c = UpdateChecker(
        fetcher: (String u) async {
          called = true;
          return '9.9.9';
        },
      );
      final UpdateCheckResult r =
          await c.check(url: 'http://example.com/latest.json');
      expect(called, isFalse);
      expect(r.hasUpdate, isFalse,
          reason: '明文通道下版本号可被中间人篡改成任意值');
    });

    test('https 照旧请求', () async {
      bool called = false;
      final UpdateChecker c = UpdateChecker(
        fetcher: (String u) async {
          called = true;
          return '9.9.9';
        },
      );
      final UpdateCheckResult r =
          await c.check(url: 'https://example.com/latest.json', local: '0.1.0');
      expect(called, isTrue);
      expect(r.hasUpdate, isTrue);
    });
  });
}
