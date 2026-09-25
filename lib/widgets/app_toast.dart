import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/adaptive.dart';

class AppToast {
  AppToast._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const Duration defaultDuration = Duration(milliseconds: 1200);

  static const double backgroundOpacity = 0.5;

  static const Color warningSurface = Color(0xFFFFB300);
  static const Color onWarningSurface = Color(0xFF1A1A1A);

  static final ValueNotifier<_ToastData?> _current =
      ValueNotifier<_ToastData?>(null);

  static OverlayEntry? _entry;

  static Timer? _timer;

  static int _gen = 0;

  static void show(
    String message, {
    bool isError = false,
    bool isWarning = false,
    Duration? duration,
  }) {
    if (message.isEmpty) return;

    final OverlayState? overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final BuildContext? ctx = navigatorKey.currentContext;
    final ThemeData? theme = ctx == null ? null : Theme.of(ctx);
    final ColorScheme cs = theme?.colorScheme ?? const ColorScheme.light();

    final Color base = isError
        ? cs.error
        : (isWarning ? warningSurface : cs.inverseSurface);
    final Color bg = base.withValues(alpha: backgroundOpacity);
    final Color fg =
        isError ? cs.onError : (isWarning ? onWarningSurface : cs.onInverseSurface);

    final int gen = ++_gen;
    _timer?.cancel();

    _current.value = _ToastData(text: message, bg: bg, fg: fg);

    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _ToastLayer());
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }

    _timer = Timer(duration ?? defaultDuration, () {
      if (gen != _gen) return;
      hide();
    });
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _current.value = null;

    _entry?.markNeedsBuild();
  }

  static void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @visibleForTesting
  static void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _gen++;
    _current.value = null;
    final OverlayEntry? e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }

  static void success(String message) => show(message);

  static void error(String message) => show(message, isError: true);

  static void warning(String message) => show(message, isWarning: true);
}

class _ToastData {
  const _ToastData({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer();

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    AppToast._current.addListener(_onData);

    if (AppToast._current.value != null) _ctrl.forward();
  }

  void _onData() {
    if (!mounted) return;
    if (AppToast._current.value != null) {
      _ctrl.forward();
    } else {
      _ctrl.reverse().whenComplete(() {
        if (mounted) AppToast._removeEntry();
      });
    }
  }

  @override
  void dispose() {
    AppToast._current.removeListener(_onData);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ToastData? data = AppToast._current.value;
    if (data == null && _ctrl.isDismissed) return const SizedBox.shrink();

    final _ToastData view = data ?? (_last ?? const _ToastData(
      text: '',
      bg: Colors.black,
      fg: Colors.white,
    ));
    if (data != null) _last = data;

    return Align(

      alignment: Alignment.bottomCenter,

      child: IgnorePointer(
        child: SafeArea(

          top: false,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Container(
                margin:
                    EdgeInsets.fromLTRB(af(context, 16), af(context, 12), af(context, 16), af(context, 16)),
                padding:
                    EdgeInsets.symmetric(horizontal: af(context, 16), vertical: af(context, 10)),
                decoration: BoxDecoration(
                  color: view.bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    view.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: view.fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastData? _last;
}
