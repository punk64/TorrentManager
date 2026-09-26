import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/controllers/server_controller.dart';
import 'package:torrent_manager/data/models/server_state.dart';
import 'package:torrent_manager/utils/formatter.dart';

void main() {
  group('第 81 轮 · 服务器卡片限速显示', () {
    test('无限速 → 显示无穷符号', () {
      expect(Formatter.setSpeedLimit(0), '(限制:∞)');
      expect(Formatter.setSpeedLimit(-1), '(限制:∞)');
    });

    test('限速按 1024 自动切换单位，保留 1 位小数', () {
      expect(Formatter.setSpeedLimit(1536), '(限制:1.5KB/s)');
      expect(Formatter.setSpeedLimit(1024), '(限制:1.0KB/s)');
      expect(Formatter.setSpeedLimit(1048576), '(限制:1.0MB/s)');
      expect(Formatter.setSpeedLimit(1572864), '(限制:1.5MB/s)');
    });

    test('★ qB：常规限速取自 server_state 的 dl/up_rate_limit（字节/秒）', () {
      final ServerState st = ServerState(
        dlRateLimit: 2 * 1024 * 1024,
        upRateLimit: 512 * 1024,
        useAltSpeedLimits: false,
      );
      final ServerSpeedLimit l = ServerSpeedLimit.fromQbState(st);
      expect(l.dl, 2097152);
      expect(l.up, 524288);
      expect(Formatter.setSpeedLimit(l.dl), '(限制:2.0MB/s)');
      expect(Formatter.setSpeedLimit(l.up), '(限制:512.0KB/s)');
    });

    test('★ qB：开了龟速模式 → 用 alt_dl/up_limit，不再是常规值', () {
      final ServerState st = ServerState(
        dlRateLimit: 10 * 1024 * 1024,
        upRateLimit: 10 * 1024 * 1024,
        useAltSpeedLimits: true,
      );
      final ServerSpeedLimit l = ServerSpeedLimit.fromQbState(
        st,
        altPrefs: <String, dynamic>{
          'alt_dl_limit': 100 * 1024,
          'alt_up_limit': 50 * 1024,
        },
      );
      expect(l.dl, 102400);
      expect(l.up, 51200);
      expect(Formatter.setSpeedLimit(l.dl), '(限制:100.0KB/s)');
    });

    test('★ qB：龟速模式开启但拿不到 alt 值 → 回退常规值，不显示 ∞', () {
      final ServerState st = ServerState(
        dlRateLimit: 1024,
        upRateLimit: 2048,
        useAltSpeedLimits: true,
      );
      final ServerSpeedLimit l = ServerSpeedLimit.fromQbState(st);
      expect(l.dl, 1024);
      expect(l.up, 2048);
    });

    test('★ TR：KB/s 换算成字节/秒，且必须看 -enabled 开关', () {
      final ServerSpeedLimit l = ServerSpeedLimit.fromTrSession(<String, dynamic>{
        'speed-limit-down': 500,
        'speed-limit-down-enabled': true,
        'speed-limit-up': 100,
        'speed-limit-up-enabled': true,
      });
      expect(l.dl, 500 * 1024);
      expect(l.up, 100 * 1024);
      expect(Formatter.setSpeedLimit(l.dl), '(限制:500.0KB/s)');
    });

    test('★ TR：开关关着（即使有值）→ 视为无限制', () {
      final ServerSpeedLimit l = ServerSpeedLimit.fromTrSession(<String, dynamic>{
        'speed-limit-down': 500,
        'speed-limit-down-enabled': false,
        'speed-limit-up': 100,
        'speed-limit-up-enabled': false,
      });
      expect(l.dl, 0);
      expect(l.up, 0);
      expect(Formatter.setSpeedLimit(l.dl), '(限制:∞)');
    });

    test('★ TR：龟速模式 → 用 alt-speed-down/up（alt 本身即开关）', () {
      final ServerSpeedLimit l = ServerSpeedLimit.fromTrSession(<String, dynamic>{
        'alt-speed-enabled': true,
        'alt-speed-down': 80,
        'alt-speed-up': 20,
        'speed-limit-down-enabled': true,
        'speed-limit-down': 900,
      });
      expect(l.dl, 80 * 1024);
      expect(l.up, 20 * 1024);
      expect(Formatter.setSpeedLimit(l.up), '(限制:20.0KB/s)');
    });

    test('没有采集到数据的服务器 → 默认 0，UI 显示 ∞（不显示 0 B/s）', () {
      const ServerSpeedLimit l = ServerSpeedLimit();
      expect(l.dl, 0);
      expect(l.up, 0);
      expect(Formatter.setSpeedLimit(l.dl), '(限制:∞)');
    });
  });
}
