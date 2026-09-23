import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'log_scope.dart';

export 'log_scope.dart';

class LogEntry {
  LogEntry(
    this.level,
    this.message, {
    this.source = AppLog.srcApp,
    this.scope,
  }) : time = DateTime.now();

  final String level;

  final String message;

  final String source;

  final LogScope? scope;

  final DateTime time;

  String? get serverId => scope?.id;

  String? get serverName => scope?.name;

  String get formattedTime =>
      DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time);
}

class AppLog {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const int maxEntries = 500;

  static const String srcApp = 'APP';
  static const String srcNet = 'NET';
  static const String srcUi = 'UI';

  static const String srcOp = 'OP';

  static const String srcView = 'VIEW';

  static Duration viewLogWindow = const Duration(seconds: 60);

  static DateTime Function() viewNow = DateTime.now;

  static final Map<String, DateTime> _viewAt = <String, DateTime>{};

  static const int viewKeyLimit = 200;

  @visibleForTesting
  static void resetViewThrottle() => _viewAt.clear();

  final entries = <LogEntry>[].obs;

  void add(
    String message, {
    String level = 'INFO',
    String source = srcApp,
    LogScope? scope,
  }) {
    entries.insert(
        0, LogEntry(level, message, source: source, scope: scope));
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
  }

  void info(String message, {String source = srcApp, LogScope? scope}) =>
      add(message, level: 'INFO', source: source, scope: scope);

  void warn(String message, {String source = srcApp, LogScope? scope}) =>
      add(message, level: 'WARN', source: source, scope: scope);

  void error(String message, {String source = srcApp, LogScope? scope}) =>
      add(message, level: 'ERROR', source: source, scope: scope);

  void net(String message, {String level = 'INFO', LogScope? scope}) =>
      add(message, level: level, source: srcNet, scope: scope);

  void ui(String message, {bool isError = false, LogScope? scope}) =>
      add(message, level: isError ? 'ERROR' : 'INFO', source: srcUi, scope: scope);

  void op(String message, {String level = 'INFO', LogScope? scope}) =>
      add(message, level: level, source: srcOp, scope: scope);

  void act(String page, String control,
      {String? target, String? detail, LogScope? scope}) {
    final String t = (target ?? '').trim();
    final String d = (detail ?? '').trim();
    final String head = t.isEmpty ? '$page › $control' : '$page › $control：$t';
    op(d.isEmpty ? head : '$head ｜ $d', scope: scope);
  }

  void view(String message,
      {String? key, String level = 'INFO', LogScope? scope}) {
    final String k = key ?? message;
    final DateTime now = viewNow();
    final DateTime? last = _viewAt[k];
    if (last != null && now.difference(last) < viewLogWindow) return;
    _viewAt[k] = now;

    if (_viewAt.length > viewKeyLimit) {
      _viewAt.removeWhere(
          (String _, DateTime at) => now.difference(at) >= viewLogWindow);
      if (_viewAt.length > viewKeyLimit) _viewAt.clear();
    }
    add(message, level: level, source: srcView, scope: scope);
  }

  static bool passScopeFilter(
    LogEntry e, {
    required Set<String> selected,
    required bool hideSystem,
  }) {
    final String? id = e.serverId;
    if (hideSystem && id == null) return false;
    if (selected.isEmpty) return true;
    if (id == null) return true;
    return selected.contains(id);
  }

  void clear() => entries.clear();
}
