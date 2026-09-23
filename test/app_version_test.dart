import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/app/app_version.dart';
import 'package:torrent_manager/utils/strings.dart';

File _pubspec() {
  final File here = File('pubspec.yaml');
  return here.existsSync() ? here : File('../pubspec.yaml');
}

String _pubspecCore(File f) {
  final RegExp re = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true);
  final RegExpMatch? m = re.firstMatch(f.readAsStringSync());
  if (m == null) {
    fail('pubspec.yaml 里找不到形如 `version: 0.0.6+7` 的行');
  }
  return m.group(1)!;
}

void main() {
  group('版本号单一真源', () {
    test('kAppVersion 必须与 pubspec 的 version 完全一致', () {
      final File f = _pubspec();
      expect(f.existsSync(), isTrue, reason: '找不到 pubspec.yaml');
      final String core = _pubspecCore(f);
      expect(kAppVersion, core,
          reason: '界面版本号（kAppVersion=$kAppVersion）与 pubspec（$core）不同步 —— '
              '这会让抽屉里显示的版本号和装进手机的 APK 版本对不上。'
              '平时无需手工改：出包时会自动同步。');
    });

    test('版本号形如 x.y.z', () {
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(kAppVersion), isTrue);
    });

    test('面向用户的版本号文案统一为「当前版本：Vx.x.x」', () {
      expect(S.versionPrefix, '当前版本：V');
      expect(S.appVersionText(), '当前版本：V$kAppVersion');

      expect(S.appVersionText(), S.appVersionText(kAppVersion));
      expect(S.appVersionText('9.9.9'), '当前版本：V9.9.9');
    });
  });
}
