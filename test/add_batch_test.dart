






import 'package:flutter_test/flutter_test.dart';

import 'package:torrent_manager/utils/add_batch.dart';

void main() {
  group('parseUrlLines', () {
    test('空文本 / 纯空白 → 空列表', () {
      expect(parseUrlLines(''), isEmpty);
      expect(parseUrlLines('   \n\t\n  '), isEmpty);
    });

    test('逐行 trim 并丢掉空行', () {
      expect(
        parseUrlLines('  a  \n\n b\n\n'),
        <String>['a', 'b'],
      );
    });

    test('Windows 换行 \\r\\n 也能拆开（trim 掉 \\r）', () {
      expect(
        parseUrlLines('magnet:?xt=a\r\nmagnet:?xt=b\r\n'),
        <String>['magnet:?xt=a', 'magnet:?xt=b'],
      );
    });

    test('完全相同的行只保留第一条（且保持原顺序）', () {
      expect(
        parseUrlLines('a\nb\na\nc\nb'),
        <String>['a', 'b', 'c'],
      );
    });

    test('xt 相同但 tr 不同的两条不算重复', () {
      const String a = 'magnet:?xt=urn:btih:AAA&tr=udp://1';
      const String b = 'magnet:?xt=urn:btih:AAA&tr=udp://2';
      expect(parseUrlLines('$a\n$b'), <String>[a, b]);
    });
  });

  group('AddBatchResult', () {
    test('初始为空', () {
      final AddBatchResult r = AddBatchResult();
      expect(r.isEmpty, isTrue);
      expect(r.total, 0);
      
      
      expect(r.allOk, isTrue);
    });

    test('成功 / 失败分别计数，total 为两者之和', () {
      final AddBatchResult r = AddBatchResult()
        ..ok('a')
        ..fail('b', '连接超时')
        ..ok('c');
      expect(r.succeeded, <String>['a', 'c']);
      expect(r.failed.map((AddBatchFailure f) => f.label), <String>['b']);
      expect(r.failed.single.reason, '连接超时');
      expect(r.total, 3);
      expect(r.isEmpty, isFalse);
      expect(r.allOk, isFalse);
    });

    test('全成功时 allOk 为真（页面据此关闭）', () {
      final AddBatchResult r = AddBatchResult()..ok('a')..ok('b');
      expect(r.allOk, isTrue);
      expect(r.failed, isEmpty);
    });

    test('失败清单保持提交顺序', () {
      final AddBatchResult r = AddBatchResult()
        ..fail('x', 'e1')
        ..ok('y')
        ..fail('z', 'e2');
      expect(r.failed.map((AddBatchFailure f) => f.label), <String>['x', 'z']);
    });
  });

  group('shortLabel', () {
    test('不超过 max 时原样返回', () {
      expect(shortLabel('abc.txt'), 'abc.txt');
      expect(shortLabel('a' * 44, max: 44), 'a' * 44);
    });

    test('超长时截断并加省略号（总长 == max）', () {
      final String s =
          shortLabel('magnet:?xt=urn:btih:${'A' * 100}', max: 44);
      expect(s.length, 44);
      expect(s.endsWith('…'), isTrue);
    });

    test('max <= 1 时退化为一个省略号（不越界）', () {
      expect(shortLabel('abcdef', max: 1), '…');
      expect(shortLabel('abcdef', max: 0), '…');
    });
  });
}
