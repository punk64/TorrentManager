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
  });

  final int written;

  final int read;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Color tint = cs.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.swap_vert, size: 11, color: tint),
          const SizedBox(width: 3),
          Text(

            '${S.ioUploadPrefix}${Formatter.setSize(read)} · '
            '${S.ioDownloadPrefix}${Formatter.setSize(written)}',
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
