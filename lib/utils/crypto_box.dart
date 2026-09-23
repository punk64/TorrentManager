import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../data/local/secure_prefs.dart';

class CryptoBox {
  CryptoBox._();

  static const String _kFileKey = 'torrentmanager.fileKey';

  static const String _appTag = 'torrentmanager';
  static const String _alg = 'AES-256-GCM';
  static const int _version = 1;
  static const int _nonceLen = 12;
  static const int _keyLen = 32;
  static const int _tagBits = 128;

  static const int _versionPortable = 2;
  static const String _kdf = 'PBKDF2-HMAC-SHA256';
  static const int _pbkdf2Iterations = 200000;
  static const int _saltLen = 16;

  static const String _kdfField = 'kdf';

  static const int minIterations = 100000;

  @visibleForTesting
  static int? testIterationsOverride;

  static int get _iterations => testIterationsOverride ?? _pbkdf2Iterations;

  static Future<Uint8List>? _keyFuture;

  static final Random _rng = Random.secure();

  static Uint8List _randomBytes(int n) {
    final Uint8List out = Uint8List(n);
    for (int i = 0; i < n; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static Future<Uint8List> _fileKey() => _keyFuture ??= _loadOrCreateKey();

  static Future<Uint8List> _loadOrCreateKey() async {
    final Object? stored = await SecurePrefs.get(_kFileKey);
    if (stored is String && stored.isNotEmpty) {
      try {
        final Uint8List k = base64Decode(stored);
        if (k.length == _keyLen) return k;
      } catch (_) {
      }
    }
    final Uint8List key = _randomBytes(_keyLen);
    await SecurePrefs.set(_kFileKey, base64Encode(key));
    return key;
  }

  static void resetKeyForTest() => _keyFuture = null;

  static Uint8List _gcm(
    bool encrypt, {
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List input,
  }) {
    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    return cipher.process(input);
  }

  static Future<String> encrypt(String plain) async {
    final Uint8List key = await _fileKey();
    final Uint8List nonce = _randomBytes(_nonceLen);
    final Uint8List data =
        _gcm(true, key: key, nonce: nonce, input: Uint8List.fromList(utf8.encode(plain)));
    return jsonEncode(<String, dynamic>{
      'app': _appTag,
      'v': _version,
      'alg': _alg,
      'nonce': base64Encode(nonce),
      'data': base64Encode(data),
    });
  }

  static bool isEnvelope(String text) {
    final Map<String, dynamic>? m = _parseEnvelope(text);
    return m != null;
  }

  static bool isPortableEnvelope(String text) {
    final Map<String, dynamic>? m = _parseEnvelope(text);
    return m != null && _isPortableMap(m);
  }

  static bool _isPortableMap(Map<String, dynamic> m) =>
      m[_kdfField] is String || m['v'] == _versionPortable;

  static Map<String, dynamic>? _parseEnvelope(String text) {
    final String t = text.trimLeft();
    if (!t.startsWith('{')) return null;
    try {
      final Object? j = jsonDecode(t);
      if (j is! Map) return null;
      final Map<String, dynamic> m = Map<String, dynamic>.from(j);
      if (m['app'] != _appTag || m['alg'] != _alg) return null;
      if (m['nonce'] is! String || m['data'] is! String) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> tryDecrypt(String text) async {
    final Map<String, dynamic>? m = _parseEnvelope(text);
    if (m == null) return null;

    if (_isPortableMap(m)) {
      throw const CryptoBoxException(
          '这是便携备份（口令加密），请用「导入便携备份」并输入口令');
    }
    final Uint8List key = await _fileKey();
    final Uint8List nonce;
    final Uint8List data;
    try {
      nonce = base64Decode(m['nonce'] as String);
      data = base64Decode(m['data'] as String);
    } catch (_) {
      throw const CryptoBoxException('备份文件格式损坏（base64 解不开）');
    }
    if (nonce.length != _nonceLen || data.length <= _tagBits ~/ 8) {
      throw const CryptoBoxException('备份文件格式损坏（长度不合法）');
    }
    try {
      final Uint8List plain = _gcm(false, key: key, nonce: nonce, input: data);
      return utf8.decode(plain);
    } on InvalidCipherTextException {
      throw const CryptoBoxException('备份文件解密失败（密钥不匹配或文件已损坏）');
    } catch (_) {
      throw const CryptoBoxException('备份文件解密失败');
    }
  }

  static Uint8List _deriveKey(
    String passphrase,
    Uint8List salt,
    int iterations,
  ) {
    final PBKDF2KeyDerivator d =
        PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    d.init(Pbkdf2Parameters(salt, iterations, _keyLen));
    return d.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  static Future<String> encryptWithPassphrase(
    String plain,
    String passphrase,
  ) async {
    if (passphrase.isEmpty) {
      throw const CryptoBoxException('口令不能为空');
    }
    final Uint8List salt = _randomBytes(_saltLen);
    final Uint8List nonce = _randomBytes(_nonceLen);
    final int iter = _iterations;
    final Uint8List key = _deriveKey(passphrase, salt, iter);
    final Uint8List data = _gcm(
      true,
      key: key,
      nonce: nonce,
      input: Uint8List.fromList(utf8.encode(plain)),
    );
    return jsonEncode(<String, dynamic>{
      'app': _appTag,
      'v': _versionPortable,
      'alg': _alg,
      _kdfField: _kdf,
      'iter': iter,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'data': base64Encode(data),
    });
  }

  static Future<String> decryptWithPassphrase(
    String text,
    String passphrase,
  ) async {
    final Map<String, dynamic>? m = _parseEnvelope(text);
    if (m == null || !_isPortableMap(m)) {
      throw const CryptoBoxException(
          '这不是便携备份文件（缺少 portable 标识）');
    }
    if (passphrase.isEmpty) {
      throw const CryptoBoxException('口令不能为空');
    }
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List data;
    try {
      salt = base64Decode(m['salt'] as String);
      nonce = base64Decode(m['nonce'] as String);
      data = base64Decode(m['data'] as String);
    } catch (_) {
      throw const CryptoBoxException('便携备份文件格式损坏（base64 解不开）');
    }

    final int iter = (m['iter'] is int) ? m['iter'] as int : 0;
    if (salt.length != _saltLen ||
        nonce.length != _nonceLen ||
        data.length <= _tagBits ~/ 8 ||
        iter <= 0) {
      throw const CryptoBoxException('便携备份文件格式损坏（参数不合法）');
    }

    if (iter < minIterations) {
      throw CryptoBoxException(
          '便携备份的加密强度不足（迭代次数 $iter，低于下限 $minIterations）：'
          '该文件可能已被篡改，已拒绝导入');
    }
    final Uint8List key = _deriveKey(passphrase, salt, iter);
    try {
      final Uint8List plain = _gcm(false, key: key, nonce: nonce, input: data);
      return utf8.decode(plain);
    } on InvalidCipherTextException {
      throw const CryptoBoxException('口令不正确，或文件已被修改/损坏');
    } catch (_) {
      throw const CryptoBoxException('便携备份解密失败');
    }
  }
}

class CryptoBoxException implements Exception {
  const CryptoBoxException(this.message);

  final String message;

  @override
  String toString() => message;
}
