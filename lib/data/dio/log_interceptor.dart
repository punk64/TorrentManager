import 'package:dio/dio.dart';

import '../../utils/app_log.dart';
import '../../utils/formatter.dart';
import '../../utils/net_error.dart';

class AppLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    recordResponse(response);
    handler.next(response);
  }

  static void recordResponse(Response<dynamic> response) {
    final RequestOptions o = response.requestOptions;
    final int code = response.statusCode ?? 0;
    final String target = '${o.method} ${_short(o.uri.toString())}';

    final LogScope? scope = _scopeOf(o);

    if (code >= 400) {
      AppLog.instance.net(
        '$target → HTTP $code${bodyBrief(response.data)}',
        level: 'ERROR',
        scope: scope,
      );
    } else if (o.method.toUpperCase() != 'GET') {
      AppLog.instance.net('$target → HTTP $code', scope: scope);
    }
  }

  static LogScope? _scopeOf(RequestOptions o) {
    final Object? id = o.extra[kLogServerIdKey];
    if (id is! String || id.isEmpty) return null;
    final Object? name = o.extra[kLogServerNameKey];
    return LogScope(id, name is String && name.isNotEmpty ? name : id);
  }

  static String bodyBrief(Object? data, [int max = 120]) {
    if (data == null) return '';
    final String raw =
        data.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return '';
    final String s = _scrub(raw);
    return ' ｜ ${s.length <= max ? s : '${s.substring(0, max)}…'}';
  }

  static String _scrub(String s) {
    String out = Formatter.maskLogText(s);

    final int b = out.toLowerCase().indexOf('basic ');
    if (b >= 0) {
      final int start = b + 6;
      int end = start;
      while (end < out.length && !_isSpace(out.codeUnitAt(end))) {
        end++;
      }
      if (end > start) {
        out = '${out.substring(0, start)}***${out.substring(end)}';
      }
    }

    final int scheme = out.indexOf('://');
    if (scheme > 0) {
      final int at = out.indexOf('@', scheme + 3);

      final int slash = out.indexOf('/', scheme + 3);
      if (at > 0 && (slash < 0 || at < slash)) {
        out = '${out.substring(0, scheme + 3)}***:***@${out.substring(at + 1)}';
      }
    }
    return out;
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    recordError(err);
    handler.next(err);
  }

  static void recordError(DioException err) {
    final RequestOptions o = err.requestOptions;
    final String target = '${o.method} ${_short(o.uri.toString())}';

    AppLog.instance.net('$target → ${NetError.describe(err)}',
        level: 'ERROR', scope: _scopeOf(o));
  }

  static String _short(String uri) {
    final int q = uri.indexOf('?');
    final String s = q < 0 ? uri : uri.substring(0, q);
    const int max = 90;
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }
}
