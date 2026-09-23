import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'formatter.dart';

class FileExport {
  FileExport._();

  static const int maxReadBytes = 2 * 1024 * 1024;

  static Future<String> writeText({
    required String fileName,
    required String content,
  }) async {
    final Directory dir = await exportDirectory();
    final File f = File('${dir.path}/${Formatter.safeFileName(fileName)}');
    await f.writeAsString(content, flush: true);
    return f.path;
  }

  static Future<Directory> exportDirectory() async {
    if (Platform.isAndroid) {
      final Directory? ext = await getExternalStorageDirectory();
      if (ext != null) {
        if (!await ext.exists()) await ext.create(recursive: true);
        return ext;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<PickedTextFile?> pickText({
    List<String> allowedExtensions = const <String>['json'],
  }) async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    final PlatformFile? f = r?.files.single;
    if (f == null) return null;

    final List<int>? bytes = f.bytes;
    if (bytes != null) {
      if (bytes.length > maxReadBytes) {
        throw const FileExportException('文件过大（超过 2 MB）');
      }
      return PickedTextFile(
        name: f.name,
        content: utf8.decode(bytes, allowMalformed: true),
      );
    }
    final String? path = f.path;
    if (path == null) return null;
    final File file = File(path);
    if (await file.length() > maxReadBytes) {
      throw const FileExportException('文件过大（超过 2 MB）');
    }
    return PickedTextFile(name: f.name, content: await file.readAsString());
  }
}

class PickedTextFile {
  const PickedTextFile({required this.name, required this.content});

  final String name;

  final String content;
}

class FileExportException implements Exception {
  const FileExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
