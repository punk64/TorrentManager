import 'dart:convert';

import 'secure_prefs.dart';

import '../models/server_data.dart';



class LocalAccount {
  const LocalAccount({
    required this.displayName,
    required this.provider,
    required this.signedInAt,
  });

  
  final String displayName;

  final String provider;

  
  final int signedInAt;

  factory LocalAccount.fromJson(Map<String, dynamic> json) {
    return LocalAccount(
      displayName: (json['displayName'] as String?) ?? 'Local user',
      provider: (json['provider'] as String?) ?? 'Local',
      signedInAt: (json['signedInAt'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'displayName': displayName,
        'provider': provider,
        'signedInAt': signedInAt,
      };

  LocalAccount copyWith({String? displayName}) => LocalAccount(
        displayName: displayName ?? this.displayName,
        provider: provider,
        signedInAt: signedInAt,
      );
}














class LocalStore {
  LocalStore._();

  static const _kServersKey = 'torrentmanager.servers';
  static const _kThemeModeKey = 'torrentmanager.themeMode';
  static const _kAccountKey = 'torrentmanager.account';
  static const _kBackupKey = 'torrentmanager.backup.servers';
  static const _kBackupAtKey = 'torrentmanager.backup.at';

  

  static Future<List<ServerData>> loadServers() async {
    
    
    
    
    final Object? v = await SecurePrefs.get(_kServersKey);
    final String raw = v is String ? v : '';
    if (raw.isEmpty) return <ServerData>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) =>
              ServerData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return <ServerData>[];
    }
  }

  static Future<void> saveServers(List<ServerData> servers) async {
    final String raw =
        jsonEncode(servers.map((ServerData s) => s.toJson()).toList());
    await SecurePrefs.set(_kServersKey, raw);
  }

  

  static Future<int> loadThemeMode() async {
    final Object? v = await SecurePrefs.get(_kThemeModeKey);
    return v is int ? v : 0;
  }

  static Future<void> saveThemeMode(int mode) =>
      SecurePrefs.set(_kThemeModeKey, mode);

  

  
  static Future<LocalAccount?> loadAccount() async {
    try {
      final Object? raw = await SecurePrefs.get(_kAccountKey);
      if (raw is! String || raw.isEmpty) return null;
      return LocalAccount.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAccount(LocalAccount account) async {
    
    await SecurePrefs.set(_kAccountKey, jsonEncode(account.toJson()));
  }

  static Future<void> clearAccount() async {
    await SecurePrefs.remove(_kAccountKey);
  }

  

  static Future<void> saveServersBackup(List<ServerData> servers) async {
    final String raw =
        jsonEncode(servers.map((ServerData s) => s.toJson()).toList());
    await SecurePrefs.set(_kBackupKey, raw);
    await SecurePrefs.set(
      _kBackupAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<List<ServerData>> loadServersBackup() async {
    final Object? v = await SecurePrefs.get(_kBackupKey);
    final String raw = v is String ? v : '';
    if (raw.isEmpty) return <ServerData>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) =>
              ServerData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return <ServerData>[];
    }
  }

  
  static Future<DateTime?> loadBackupAt() async {
    final Object? v = await SecurePrefs.get(_kBackupAtKey);
    if (v is! int || v <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(v);
  }

  
  static Future<bool> hasBackup() async {
    
    final Object? v = await SecurePrefs.get(_kBackupKey);
    return v is String && v.isNotEmpty;
  }

  static Future<void> clearBackup() async {
    await SecurePrefs.remove(_kBackupKey);
    await SecurePrefs.remove(_kBackupAtKey);
  }

  
  
  
  
  
  
  
  
  
  
  

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  

  

  
  
  
  
  
  
  
  static List<ServerData> parseServersJson(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <ServerData>[];
    }
    final List<dynamic> rows =
        decoded is List<dynamic> ? decoded : <dynamic>[decoded];
    final List<ServerData> out = <ServerData>[];
    for (final dynamic e in rows) {
      if (e is! Map) continue; 
      try {
        out.add(ServerData.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        
      }
    }
    return out;
  }
}
