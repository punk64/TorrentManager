import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/qbittorrent/qb_method.dart';
import 'package:torrent_manager/utils/net_error.dart';

void main() {
  QbMethod qbWith({
    ConnErrorKind? kind,
    String? err,
    bool banned = false,
    bool missing = false,
  }) {
    final QbMethod c = QbMethod();
    c.lastLoginKind = kind;
    c.lastLoginError = err;
    c.lastLoginBanned = banned;
    c.lastLoginMissingCreds = missing;
    return c;
  }

  group('★ 第 79 轮：断网 = 可重试，不是 fatal', () {
    test('探测捕获到 unreachable → 归类 unreachable（退避重试，不挂起）', () {
      final ConnErrorKind k = ServerController.qbKindOf(
        qbWith(kind: ConnErrorKind.unreachable, err: '网络不可达'),
      );
      expect(k, ConnErrorKind.unreachable);
      expect(k.isFatal, isFalse,
          reason: '★ 断网一旦判成 fatal 就会立刻挂起自动重试 —— 这正是旧版的行为');
      expect(k.isRetryable, isTrue);
    });

    test('classify 把"解析失败"判成 addressInvalid，靠文案兜回 unreachable', () {

      expect(NetError.classify(Exception('failed host lookup')),
          ConnErrorKind.addressInvalid);

      final ConnErrorKind k = ServerController.qbKindOf(
        qbWith(
          kind: ConnErrorKind.addressInvalid,
          err: '无法解析服务器地址（域名写错，或当前网络没有 DNS）',
        ),
      );
      expect(k, ConnErrorKind.unreachable,
          reason: '★ 与 TR 的 _isNetworkReason 口径一致：解析失败也算网络问题');
    });

    test('没有任何网络迹象时，仍保持原有语义（封禁 / 缺凭据 / 认证失败）', () {
      expect(ServerController.qbKindOf(qbWith(banned: true)),
          ConnErrorKind.ipBanned);
      expect(ServerController.qbKindOf(qbWith(missing: true)),
          ConnErrorKind.missingConfig);
      expect(
        ServerController.qbKindOf(qbWith(err: '账号或密码错误（HTTP 401）')),
        ConnErrorKind.authFailed,
      );
    });

    test('退避序列存在且递增（断网后会 3→6→12→30s 重试，而不是一击挂起）', () {
      expect(ServerController.kBackoffSeconds, <int>[3, 6, 12, 30]);
      expect(ServerController.kMaxConsecutiveFailures, 10);
    });
  });
}
