import 'package:dio/dio.dart';

import '../../utils/strings.dart';




















class RedirectInterceptor extends Interceptor {
  RedirectInterceptor({this.dio, this.maxHops = 3});

  
  final Dio? dio;

  
  final int maxHops;

  
  
  static const String _kHops = 'torrentmanager.redirectHops';

  
  
  
  
  
  static bool isAllowed(Uri from, Uri to) {
    if (from.host.isEmpty || to.host.isEmpty) return false;
    if (from.host != to.host) return false;
    if (from.scheme == 'https' && to.scheme == 'http') return false;
    return true;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final Dio? d = dio;
    final int code = response.statusCode ?? 0;
    
    if (d == null || code < 300 || code >= 400) {
      handler.next(response);
      return;
    }
    final String? loc = response.headers.value('location');
    final RequestOptions ro = response.requestOptions;
    if (loc == null || loc.isEmpty) {
      handler.next(response);
      return;
    }
    final Uri from = ro.uri;
    final Uri? to = Uri.tryParse(loc) == null ? null : from.resolve(loc);
    if (to == null) {
      
      handler.next(response);
      return;
    }
    if (!isAllowed(from, to)) {
      handler.reject(
        DioException(
          requestOptions: ro,
          response: response,
          type: DioExceptionType.badResponse,
          message: '拒绝跨主机重定向（${from.host} → ${to.host}）：'
              '会话凭据不会转发到其它主机',
        ),
        true,
      );
      return;
    }
    final int hops = (ro.extra[_kHops] as int? ?? 0) + 1;
    if (hops > maxHops) {
      handler.reject(
        DioException(
          requestOptions: ro,
          response: response,
          type: DioExceptionType.badResponse,
          message: S.netTooManyRedirects,
        ),
        true,
      );
      return;
    }
    
    
    ro.extra[_kHops] = hops;
    
    ro.path = to.toString();
    try {
      final Response<dynamic> r = await d.fetch<dynamic>(ro);
      handler.resolve(r);
    } on DioException catch (e) {
      handler.reject(e, true);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
