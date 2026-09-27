import 'package:flutter/material.dart';

import '../utils/fmt_cache.dart';

class StatusStyle {
  static const int _cacheLimit = 2048;

  static final FmtCache<IconData> _cacheIcon = FmtCache<IconData>(_cacheLimit);
  static final FmtCache<int> _cacheColorKind = FmtCache<int>(_cacheLimit);

  @visibleForTesting
  static void clearCache() {
    _cacheIcon.clear();
    _cacheColorKind.clear();
  }

  static Color setStatusColor(String state, ColorScheme cs) {
    switch (_statusColorKind(state)) {
      case 0:
        return cs.error;
      case 1:
        return cs.outline;
      case 2:
        return cs.tertiary;
      case 3:
        return cs.primary;
      case 4:
        return cs.secondary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  static int _statusColorKind(String state) {
    final int? hit = _cacheColorKind.get(state);
    if (hit != null) return hit;
    final String s = state.toLowerCase();
    final int out;
    if (s.contains('error') || s.contains('missingfiles')) {
      out = 0;
    } else if (s.contains('paused') || s.contains('stop')) {
      out = 1;
    } else if (s.contains('check') ||
        s.contains('moving') ||
        s.contains('allocating')) {
      out = 2;
    } else if (s.contains('up') || s.contains('seed') || s.contains('upload')) {
      out = 3;
    } else if (s.contains('dl') ||
        s.contains('download') ||
        s.contains('meta')) {
      out = 4;
    } else {
      out = 5;
    }
    _cacheColorKind.put(state, out);
    return out;
  }

  static IconData statusIcon(String state) {
    final IconData? hit = _cacheIcon.get(state);
    if (hit != null) return hit;
    final IconData out = _calcStatusIcon(state);
    _cacheIcon.put(state, out);
    return out;
  }

  static IconData _calcStatusIcon(String state) {
    final String s = state.toLowerCase();
    if (s.contains('error') || s.contains('missingfiles')) return Icons.error;

    if (s.contains('paused') || s.contains('stop')) return Icons.pause;
    if (s.contains('check')) return Icons.fact_check_outlined;
    if (s.contains('moving') || s.contains('allocating')) return Icons.sync;
    if (s.contains('queued')) return Icons.pending_outlined;
    if (s.contains('meta')) return Icons.language;
    if (s.contains('up') || s.contains('seed') || s.contains('upload')) {
      return Icons.arrow_circle_up;
    }
    if (s.contains('dl') || s.contains('download')) {
      return Icons.arrow_circle_down;
    }
    return Icons.help_outline;
  }

  static IconData iconExtension(String fileName) {
    final String n = fileName.toLowerCase().trim();
    if (n.isEmpty) return Icons.insert_drive_file;
    if (!n.contains('.')) return Icons.folder;

    final String ext = n.split('.').last;
    const Set<String> image = <String>{
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'tiff',
      'heic',
      'svg',
    };
    const Set<String> audio = <String>{
      'mp3',
      'flac',
      'wav',
      'aac',
      'm4a',
      'ogg',
      'ape',
      'wma',
      'dsf',
    };
    const Set<String> video = <String>{
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'rmvb',
      'ts',
      'm2ts',
      'mpg',
    };
    const Set<String> archive = <String>{
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
      'bz2',
      'xz',
      'iso',
    };
    const Set<String> doc = <String>{
      'pdf',
      'doc',
      'docx',
      'txt',
      'epub',
      'mobi',
      'azw3',
      'chm',
      'rtf',
      'md',
    };

    if (image.contains(ext)) return Icons.image;
    if (audio.contains(ext)) return Icons.audio_file;
    if (video.contains(ext)) return Icons.local_movies;
    if (archive.contains(ext)) return Icons.compress;
    if (doc.contains(ext)) return Icons.description;
    if (ext == 'exe' || ext == 'msi' || ext == 'apk') return Icons.memory;
    return Icons.insert_drive_file;
  }
}
