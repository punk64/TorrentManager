import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/data/dio/log_interceptor.dart';
import 'package:torrent_manager/utils/app_log.dart';
import 'package:torrent_manager/utils/formatter.dart';

RequestOptions _req(String method, String path) => RequestOptions(
      method: method,
      path: path,
      baseUrl: 'http://192.168.1.5:8080',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLog.instance.clear());

  test('Toast 会写入应用日志，且标记来源 UI', () {
    Formatter.showToast('已添加服务器');
    expect(AppLog.instance.entries.length, 1);
    expect(AppLog.instance.entries.first.message, '已添加服务器');
    expect(AppLog.instance.entries.first.level, 'INFO');
    expect(AppLog.instance.entries.first.source, AppLog.srcUi);

    Formatter.showToast('连接失败', isError: true);
    expect(AppLog.instance.entries.first.level, 'ERROR');
  });

  test('长消息压成一行并截断（日志条目不该带换行）', () {
    Formatter.showToast('第一行\n第二行   空格很多');
    expect(AppLog.instance.entries.first.message.contains('\n'), isFalse);
  });

  test('网络：写操作记 INFO，成功的 GET 不记（否则 3s 轮询会刷爆日志）', () {
    AppLogInterceptor.recordResponse(Response<dynamic>(
      requestOptions: _req('GET', '/api/v2/torrents/info'),
      statusCode: 200,
    ));
    expect(AppLog.instance.entries, isEmpty,
        reason: '轮询用的 GET 不该进日志，否则 500 条上限 20 分钟就刷没了');

    AppLogInterceptor.recordResponse(Response<dynamic>(
      requestOptions: _req('POST', '/api/v2/torrents/delete'),
      statusCode: 200,
    ));
    expect(AppLog.instance.entries.length, 1);
    expect(AppLog.instance.entries.first.source, AppLog.srcNet);
    expect(AppLog.instance.entries.first.message,
        contains('POST http://192.168.1.5:8080/api/v2/torrents/delete'));
  });

  test('网络：4xx 记 ERROR', () {
    AppLogInterceptor.recordResponse(Response<dynamic>(
      requestOptions: _req('POST', '/api/v2/auth/login'),
      statusCode: 404,
    ));
    expect(AppLog.instance.entries.first.level, 'ERROR');
    expect(AppLog.instance.entries.first.message, contains('HTTP 404'));
  });

  test('网络：异常走 recordError，写进日志的是一句中文原因', () {
    AppLogInterceptor.recordError(DioException(
      requestOptions: _req('GET', '/api/v2/app/version'),
      type: DioExceptionType.connectionError,
      error: 'Connection refused',
    ));
    final LogEntry e = AppLog.instance.entries.first;
    expect(e.level, 'ERROR');
    expect(e.source, AppLog.srcNet);
    expect(e.message, contains('连接被拒绝'),
        reason: 'NetError.describe 应把英文底层错误压成一句中文');
  });

  test('日志有上限，超出后丢最旧的', () {
    for (int i = 0; i < AppLog.maxEntries + 20; i++) {
      AppLog.instance.info('m$i');
    }
    expect(AppLog.instance.entries.length, AppLog.maxEntries);

    expect(AppLog.instance.entries.first.message, 'm${AppLog.maxEntries + 19}');
  });
}
