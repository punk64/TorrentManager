





import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:torrent_manager/app/bindings.dart';
import 'package:torrent_manager/controllers/theme_controller.dart';
import 'package:torrent_manager/data/models/server_data.dart';
import 'package:torrent_manager/data/transmission/tr_method.dart';
import 'package:torrent_manager/pages/server_dialog.dart';
import 'package:torrent_manager/utils/formatter.dart';
import 'package:torrent_manager/utils/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('① 密码框「显示 / 隐藏」切换', () {
    testWidgets('点击眼睛图标在遮蔽与明文之间切换', (WidgetTester tester) async {
      Get.testMode = true;
      Get.reset();
      Get.put(ThemeController(), permanent: true);

      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: Builder(
          builder: (BuildContext ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showServerDialog(ctx),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      
      
      final Finder pwd = find.byType(TextFormField).at(6);
      Finder editableOf(Finder f) =>
          find.descendant(of: f, matching: find.byType(EditableText));

      
      
      await tester.ensureVisible(pwd);
      await tester.pumpAndSettle();

      
      expect(tester.widget<EditableText>(editableOf(pwd)).obscureText, isTrue);

      
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is Semantics && w.properties.label == S.srvShowPassword),
        findsOneWidget,
        reason: '★ 切换按钮需带无障碍标签',
      );
      expect(find.byTooltip(S.srvShowPassword), findsOneWidget,
          reason: '★ 切换按钮需带 title 提示');

      
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editableOf(pwd)).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editableOf(pwd)).obscureText, isTrue);
    });

    testWidgets('切换不影响输入内容与必填校验', (WidgetTester tester) async {
      Get.testMode = true;
      Get.reset();
      Get.put(ThemeController(), permanent: true);

      await tester.pumpWidget(GetMaterialApp(
        initialBinding: AppBinding(),
        home: Builder(
          builder: (BuildContext ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showServerDialog(ctx),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      final Finder pwd = find.byType(TextFormField).at(6);
      await tester.ensureVisible(pwd);
      await tester.pumpAndSettle();
      await tester.enterText(pwd, 'p@ss word 含空格');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      
      expect(find.text('p@ss word 含空格'), findsWidgets,
          reason: '★ 切换只改渲染开关，不该清空或改动已输入内容');

      
      await tester.enterText(find.byType(TextFormField).at(1), '192.168.1.9');
      await tester.tap(find.text(S.srvSaveShort));
      await tester.pumpAndSettle();
      expect(find.text(S.srvEnterUsername), findsOneWidget,
          reason: '★ 原有必填校验仍然生效');
    });
  });

  group('② TR 登录：Basic 鉴权必须真的发出去', () {
    ServerData trServer({String? user, String? pass}) => ServerData(
          id: 'tr1',
          name: 'TR',
          type: 'transmission',
          host: '192.168.1.9',
          port: 9091,
          useHttps: false,
          username: user,
          password: pass,
        );

    test('凭据编码：空格与中文不被破坏（UTF-8 + base64）', () {
      final String h = Formatter.getAuthentication('us er', 'p@ss 密码');
      expect(h, startsWith('Basic '));
      final String decoded =
          utf8.decode(base64.decode(h.substring('Basic '.length)));
      expect(decoded, 'us er:p@ss 密码',
          reason: '★ 必须走 base64(utf8(...))，空格与非 ASCII 都不能被吞');
    });

    test('★ 登录请求带 Authorization，且 409 握手后回带 session id', () async {
      final List<RequestOptions> reqs = <RequestOptions>[];
      int n = 0;
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          reqs.add(o);
          n++;
          if (n == 1) {
            
            h.resolve(Response<dynamic>(
              requestOptions: o,
              statusCode: 409,
              headers: Headers.fromMap(<String, List<String>>{
                'x-transmission-session-id': <String>['SID-123'],
              }),
            ));
          } else {
            h.resolve(Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: <String, dynamic>{
                'result': 'success',
                'arguments': <String, dynamic>{},
              },
            ));
          }
        },
      ));

      final TrMethod tr = TrMethod(dio: dio);
      final TrLoginResult r =
          await tr.updateTrServerCookie(trServer(user: 'admin', pass: 'p@ss 密码'));

      expect(r.ok, isTrue, reason: '握手 + 鉴权都通过才算登录成功');
      expect(reqs.length, 2, reason: '第一次 409 握手，第二次带 sid 重试');

      
      expect(reqs.first.headers['Authorization'], isNotNull,
          reason: '★ TR 请求必须带 Basic 鉴权头');
      expect(reqs.first.headers['Authorization'], startsWith('Basic '));
      expect(
        utf8.decode(base64.decode(reqs.first.headers['Authorization']!
            .substring('Basic '.length))),
        'admin:p@ss 密码',
      );

      
      expect(reqs.last.headers['X-Transmission-Session-Id'], 'SID-123');
    });

    test('未填账号时不发送 Authorization（不把空凭据丢给服务端）', () async {
      final List<RequestOptions> reqs = <RequestOptions>[];
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          reqs.add(o);
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

      final TrMethod tr = TrMethod(dio: dio);
      await tr.updateTrServerCookie(trServer());
      expect(reqs.first.headers['Authorization'], isNull,
          reason: '★ 没填账号就不该发 Basic 头');
    });

    test('401 时能分清「密码错」与「本机没填账号」', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.9:9091'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          h.resolve(Response<dynamic>(requestOptions: o, statusCode: 401));
        },
      ));
      final TrMethod withCred = TrMethod(dio: dio);
      final TrLoginResult a =
          await withCred.updateTrServerCookie(trServer(user: 'admin', pass: 'x'));
      expect(a.ok, isFalse);
      expect(a.reason, contains('密码'),
          reason: '★ 发了凭据还 401 → 应判定为账号或密码错误');

      final TrMethod noCred = TrMethod(dio: dio);
      final TrLoginResult b = await noCred.updateTrServerCookie(trServer());
      expect(b.ok, isFalse);
      expect(b.reason, contains('未填写账号'),
          reason: '★ 没发凭据也 401 → 应提示本机未配置账号，而不是谎称密码错');
    });
  });
}
