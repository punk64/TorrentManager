import 'package:dio/dio.dart';

import 'strings.dart';

enum ConnErrorKind {
  none,

  missingConfig,

  authFailed,

  ipBanned,

  addressInvalid,

  unreachable,

  unknown,
}

extension ConnErrorKindX on ConnErrorKind {
  bool get isFatal =>
      this == ConnErrorKind.missingConfig ||
      this == ConnErrorKind.authFailed ||
      this == ConnErrorKind.ipBanned ||
      this == ConnErrorKind.addressInvalid;

  bool get isRetryable => this == ConnErrorKind.unreachable ||
      this == ConnErrorKind.unknown;
}

class NetError {
  NetError._();

  static const int maxFallbackLength = 2000;

  static bool _isBanned(DioException e) {
    final String body = e.response?.data?.toString().toLowerCase() ?? '';
    final String inner = e.error?.toString().toLowerCase() ?? '';
    return body.contains('banned') || inner.contains('banned');
  }

  static String describe(Object e) {
    String raw = e.toString();
    if (e is DioException) {
      final Object? inner = e.error;
      if (inner != null) raw = '$raw ${inner.toString()}';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return S.srvConnTimeout;
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return S.srvTimeout;
        case DioExceptionType.badCertificate:

          return 'HTTPS 证书校验失败：请为服务端配置受信任的证书，'
              '或在客户端信任该自签名证书（改用 http 会明文传输账号密码）';
        case DioExceptionType.badResponse:
          final int? code = e.response?.statusCode;

          if (_isBanned(e)) return S.srvIpBanned;

          if (code == 401) return '账号或密码错误（HTTP 401）';
          if (code == 403) {
            return '服务器拒绝访问：未登录或会话已失效（HTTP 403）';
          }
          if (code == 404) return '地址或端口不对，接口未找到（HTTP 404）';
          return '服务器返回异常状态 HTTP ${code ?? '?'}';
        case DioExceptionType.connectionError:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          break;
      }
    }

    final String low = raw.toLowerCase();
    if (low.contains('banned')) return S.srvIpBanned;
    if (low.contains('no host specified')) return '尚未选择服务器';
    if (low.contains('failed host lookup') ||
        low.contains('nodename nor servname') ||
        low.contains('name or service not known')) {
      return '无法解析服务器地址（域名写错，或当前网络没有 DNS）';
    }
    if (low.contains('connection refused')) return '连接被拒绝（端口不对，或服务未启动）';
    if (low.contains('no route to host') ||
        low.contains('network is unreachable')) {
      return '网络不可达（不在同一局域网，或 VPN / 代理未连）';
    }
    if (low.contains('timed out')) return S.srvConnTimeout;
    if (low.contains('certificate') || low.contains('handshake')) {
      return 'HTTPS 握手 / 证书失败';
    }

    String scrubbed = raw.replaceAll(
      RegExp(r'\s*uri:\s*\S+', caseSensitive: false),
      ' ',
    );
    scrubbed = scrubbed.replaceAll(
      RegExp(r'https?://[^\s/]+', caseSensitive: false),
      'http://…',
    );

    final String one = scrubbed.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= maxFallbackLength
        ? one
        : '${one.substring(0, maxFallbackLength)}…';
  }

  static ConnErrorKind classify(Object e) {
    if (e is DioException) {
      if (_isBanned(e)) return ConnErrorKind.ipBanned;

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return ConnErrorKind.unreachable;
        case DioExceptionType.badCertificate:

          return ConnErrorKind.addressInvalid;
        case DioExceptionType.badResponse:
          final int? code = e.response?.statusCode;
          if (code == 401 || code == 403) return ConnErrorKind.authFailed;
          if (code == 404) return ConnErrorKind.addressInvalid;
          return ConnErrorKind.unknown;
        case DioExceptionType.connectionError:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          break;
      }
      final Object? inner = e.error;
      if (inner != null) {
        final ConnErrorKind k = classify(inner);
        if (k != ConnErrorKind.unknown) return k;
      }
    }

    final String low = e.toString().toLowerCase();
    if (low.contains('banned')) return ConnErrorKind.ipBanned;
    if (low.contains('no host specified')) return ConnErrorKind.missingConfig;
    if (low.contains('failed host lookup') ||
        low.contains('nodename nor servname') ||
        low.contains('name or service not known') ||
        low.contains('no address associated with hostname')) {
      return ConnErrorKind.addressInvalid;
    }
    if (low.contains('connection refused')) return ConnErrorKind.unreachable;
    if (low.contains('no route to host') ||
        low.contains('network is unreachable')) {
      return ConnErrorKind.unreachable;
    }
    if (low.contains('timed out') || low.contains('timeout')) {
      return ConnErrorKind.unreachable;
    }
    if (low.contains('certificate') || low.contains('handshake')) {
      return ConnErrorKind.addressInvalid;
    }
    return ConnErrorKind.unknown;
  }
}
