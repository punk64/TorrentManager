import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/server_controller.dart';
import '../utils/app_log.dart';
import '../app/adaptive.dart';

class ListLoadingPlaceholder extends StatefulWidget {
  const ListLoadingPlaceholder({super.key});

  @override
  State<ListLoadingPlaceholder> createState() => _ListLoadingPlaceholderState();
}

class _ListLoadingPlaceholderState extends State<ListLoadingPlaceholder> {
  @override
  void initState() {
    super.initState();
    AppLog.instance.view(
      '种子列表 骨架屏已显示（等待首屏数据）',
      key: '骨架屏:显示',
    );
  }

  @override
  void dispose() {
    AppLog.instance.view(
      '种子列表 骨架屏已撤下（首屏数据到达）',
      key: '骨架屏:撤下',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData th = Theme.of(context);
    final ColorScheme cs = th.colorScheme;
    return Obx(() {
      final ServerController sc = Get.find<ServerController>();
      final String? id = sc.current.value?.id;
      final String text =
          (id == null ? null : sc.stageTextOf(id)) ?? '正在连接服务器…';
      return Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(af(context, 16), af(context, 14), af(context, 16), af(context, 8)),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: af(context, 13),
                  height: af(context, 13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
                SizedBox(width: af(context, 10)),
                Expanded(
                  child: Text(
                    text,
                    style: th.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: af(context, 12)),
              itemCount: 6,
              itemBuilder: (BuildContext _, int __) => const _SkeletonCard(),
            ),
          ),
        ],
      );
    });
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color base = cs.onSurface.withValues(alpha: 0.08);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: af(context, 12), vertical: 5),
      padding: EdgeInsets.all(af(context, 12)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: SizedBox(width: double.infinity, height: af(context, 13)),
          ),
          SizedBox(height: af(context, 9)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: SizedBox(width: af(context, 150), height: 11),
          ),
          SizedBox(height: af(context, 10)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(AppTheme.radiusBar),
            ),
            child: const SizedBox(width: double.infinity, height: 6),
          ),
        ],
      ),
    );
  }
}
