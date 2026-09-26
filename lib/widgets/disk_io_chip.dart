import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../utils/formatter.dart';
import '../utils/strings.dart';
import '../app/adaptive.dart';

class DiskIoChip extends StatelessWidget {
  const DiskIoChip({
    super.key,
    required this.written,
    required this.read,
    this.compact = false,
  });

  final int written;

  final int read;

  /// 紧凑文案 `↑ X · ↓ Y`（种子卡片信息带用，宽度约为全称的一半）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Color tint = cs.onSecondaryContainer;
    final String text = compact
        ? '${S.upArrow}${Formatter.setSize(read)} · '
            '${S.downArrow}${Formatter.setSize(written)}'
        : '${S.ioUploadPrefix}${Formatter.setSize(read)} · '
            '${S.ioDownloadPrefix}${Formatter.setSize(written)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!compact) ...<Widget>[
            Icon(Icons.swap_vert, size: af(context, 11), color: tint),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: af(context, 10),
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
