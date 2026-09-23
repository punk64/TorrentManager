import 'dart:async';
import 'dart:io';

import '../data/models/server_data.dart';

class LanDetector {
  LanDetector._();

  static const Duration kProbeTimeout = Duration(milliseconds: 600);

  static Future<bool> Function(ServerData)? overrideProbe;

  static Future<bool> Function(String host, int port)? overrideTcp;

  static Future<bool> isOnLan(ServerData s) async {
    if (!s.hasLan) return false; 
    return overrideProbe != null ? overrideProbe!(s) : _realIsOnLan(s);
  }

  static Future<bool> _realIsOnLan(ServerData s) async {
    if (!s.hasLan) return false;
    return _tcpConfirm(s.lanHost!, s.lanPort!, kProbeTimeout);
  }

  static Future<bool> _tcpConfirm(String host, int port, Duration timeout) async {
    if (overrideTcp != null) return overrideTcp!(host, port);
    Socket? sock;
    try {
      sock = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    } finally {
      try {
        await sock?.close();
      } catch (_) {
      }
    }
  }
}
