import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

























class SecurePrefs {
  SecurePrefs._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  
  static const String _kMigrated = 'torrentmanager.prefsEncrypted.v1';

  
  static final Map<String, String> _mem = <String, String>{};

  static Future<void>? _ready;

  
  static Map<String, String>? _memBackend;

  

  
  
  
  
  
  
  
  
  
  static void useMemoryBackendForTest([Map<String, Object?>? initial]) {
    final Map<String, String> enc = <String, String>{};
    if (initial != null) {
      initial.forEach((String k, Object? v) {
        if (v != null) enc[k] = _encode(v);
      });
    }
    _memBackend = enc;
    _mem
      ..clear()
      ..addAll(enc);
    
    
    
    
    
    
    
    
    _ready = null;
  }

  
  
  
  
  static void resetCacheForTest() {
    if (_memBackend == null) return;
    _mem.clear();
    _ready = null;
  }

  
  static Map<String, Object?> snapshotForTest() {
    final Map<String, Object?> out = <String, Object?>{};
    _mem.forEach((String k, String v) => out[k] = _decode(v));
    return out;
  }

  

  
  
  
  
  
  
  static Future<void> ensureReady() {
    final Map<String, String>? backend = _memBackend;
    if (backend != null) {
      _mem.addAll(backend);
      return Future<void>.value();
    }
    return _ready ??= _init();
  }

  static Future<void> _init() async {
    final Map<String, String>? backend = _memBackend;
    if (backend != null) {
      
      _mem.addAll(backend);
      return;
    }
    try {
      final Map<String, String> all = await _secure.readAll();
      _mem.addAll(all);
    } catch (_) {
      
    }
    if (_mem.containsKey(_kMigrated)) return;
    await _migrateLegacy();
  }

  
  
  
  
  static Future<void> _migrateLegacy() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final Set<String> keys = sp.getKeys();
      for (final String k in keys) {
        final Object? v = sp.get(k);
        if (v == null) continue;
        
        if (_mem.containsKey(k)) continue;
        final String enc = _encode(v);
        _mem[k] = enc;
        await _secure.write(key: k, value: enc);
      }
      
      if (keys.isNotEmpty) await sp.clear();
      _mem[_kMigrated] = 'i:1';
      await _secure.write(key: _kMigrated, value: 'i:1');
    } catch (_) {
      
    }
  }

  static String _encode(Object v) {
    if (v is bool) return 'b:${v ? 1 : 0}';
    if (v is int) return 'i:$v';
    if (v is double) return 'd:$v';
    return 's:$v';
  }

  static Object? _decode(String raw) {
    if (raw.length < 2 || raw[1] != ':') return raw;
    final String body = raw.substring(2);
    switch (raw[0]) {
      case 'b':
        return body == '1';
      case 'i':
        
        return int.tryParse(body) ?? body;
      case 'd':
        return double.tryParse(body) ?? body;
      default:
        return body;
    }
  }

  static Future<String?> _readRaw(String key) async {
    await ensureReady();
    final String? cached = _mem[key];
    if (cached != null) return cached;
    final Map<String, String>? backend = _memBackend;
    if (backend != null) {
      
      final String? v = backend[key];
      if (v != null) _mem[key] = v;
      return v;
    }
    try {
      final String? v = await _secure.read(key: key);
      if (v != null) _mem[key] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  
  static Future<Object?> get(String key) async {
    final String? raw = await _readRaw(key);
    return raw == null ? null : _decode(raw);
  }

  
  static Future<void> set(String key, Object? value) async {
    await ensureReady();
    if (value == null) {
      await remove(key);
      return;
    }
    final String enc = _encode(value);
    _mem[key] = enc;
    final Map<String, String>? backend = _memBackend;
    if (backend != null) {
      backend[key] = enc;
      return;
    }
    try {
      await _secure.write(key: key, value: enc);
    } catch (_) {
      
    }
  }

  static Future<void> remove(String key) async {
    await ensureReady();
    _mem.remove(key);
    final Map<String, String>? backend = _memBackend;
    if (backend != null) {
      backend.remove(key);
      return;
    }
    try {
      await _secure.delete(key: key);
    } catch (_) {
      
    }
  }
}
