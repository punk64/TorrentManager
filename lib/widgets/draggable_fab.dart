import 'dart:async';
import 'dart:io';

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/adaptive.dart';

class DraggableFab extends StatefulWidget {
  const DraggableFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.width = 60,
    this.height = 46,
    this.radius = AppTheme.radius,
    this.idleHideDelay = const Duration(seconds: 3),
    this.insetRatio = 0.2,
    this.topInset = 0,
    this.initialY,
    this.initialYRatio,
  });

  static const double listPageInitialYRatio = 0.8;

  static const double dragOvershoot = 24;

  final VoidCallback onPressed;

  final IconData icon;

  final double width;
  final double height;

  final double radius;

  final Duration idleHideDelay;

  final double insetRatio;

  final double topInset;

  final double? initialY;

  final double? initialYRatio;

  @override
  State<DraggableFab> createState() => DraggableFabState();
}

class DraggableFabState extends State<DraggableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Animation<Offset>? _tween;

  Offset? _pos;

  Size _area = Size.zero;

  bool _inset = false;

  double _savedX = 0;

  bool _userMoved = false;

  Timer? _idle;

  Timer? _holdRect;

  bool _started = false;

  bool _snapping = false;

  double get _diameter => widget.height;

  double get _restShift => (widget.width - _diameter) / 2;

  bool get _isRect => _snapping || _inset;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )
      ..addListener(() {
        final Animation<Offset>? t = _tween;
        if (t != null && mounted) setState(() => _pos = t.value);
      })
      ..addStatusListener((AnimationStatus s) {
        if (s != AnimationStatus.completed || !mounted) return;

        if (_snapping) setState(() => _snapping = false);

        if (!_inset) _scheduleIdle();
      });
  }

  @override
  void didUpdateWidget(covariant DraggableFab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_userMoved &&
        !_inset &&
        !_anim.isAnimating &&
        widget.initialY != oldWidget.initialY &&
        widget.initialY != null &&
        _pos != null &&
        _area != Size.zero) {
      final double y = _clamp(Offset(_pos!.dx, widget.initialY!)).dy;
      if ((_pos!.dy - y).abs() > 0.5) {
        setState(() => _pos = Offset(_pos!.dx, y));
      }
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _holdRect?.cancel();
    _anim.dispose();
    super.dispose();
  }

  double get _minY => 0;

  double get _minX => -_restShift;

  double get _maxX =>
      (_area.width - _diameter - _restShift).clamp(_minX, 1e9);

  double get _maxY =>
      (_area.height - widget.height).clamp(_minY, 1e9);

  Offset _clamp(Offset p) => Offset(
        p.dx.clamp(_minX, _maxX),
        p.dy.clamp(_minY, _maxY),
      );

  Offset _clampDrag(Offset p) => Offset(
        p.dx.clamp(
            _minX - DraggableFab.dragOvershoot, _maxX + DraggableFab.dragOvershoot),
        p.dy.clamp(_minY, _maxY),
      );

  bool _isLeftSide(Offset p) =>
      p.dx + _restShift + _diameter / 2 < _area.width / 2;

  double _dockedX(bool left) => left ? _minX : _maxX;

  void _animateTo(Offset target, {Curve curve = Curves.easeOutBack}) {
    _tween = Tween<Offset>(begin: _pos ?? target, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: curve));
    _anim.forward(from: 0);
  }

  void _syncInitial(double screenH) {
    if (screenH <= 0 || _area.width <= 0 || _area.height <= 0) return;
    if (_userMoved) {
      _pos ??= _initialPos(screenH);
      return;
    }
    if (_inset || _anim.isAnimating) return;
    _pos = _initialPos(screenH);
  }

  Offset _initialPos(double screenH) {
    final double y;
    if (widget.initialYRatio != null) {
      final double screenY =
          screenH * widget.initialYRatio! - widget.height / 2;
      y = (screenY - widget.topInset).clamp(_minY, _maxY);
    } else if (widget.initialY != null) {
      y = widget.initialY!.clamp(_minY, _maxY);
    } else {
      y = _maxY;
    }
    return Offset(_maxX, y);
  }

  static final bool _testMode =
      Platform.environment.containsKey('FLUTTER_TEST');

  void _scheduleIdle() {
    _idle?.cancel();
    if (_testMode) return;
    _idle = Timer(widget.idleHideDelay, _insetToEdge);
  }

  void _insetToEdge() {
    if (!mounted || _pos == null || _inset || _area == Size.zero) return;
    final bool left = _isLeftSide(_pos!);
    _savedX = _pos!.dx;

    final double visible = widget.width * widget.insetRatio;
    final double targetX = left ? -widget.width + visible : _area.width - visible;
    setState(() => _inset = true);
    _animateTo(Offset(targetX, _pos!.dy), curve: Curves.easeInOut);
  }

  @visibleForTesting
  void debugInsetToEdge() => _insetToEdge();

  void _restore() {
    if (!mounted || _pos == null || !_inset) return;
    setState(() => _inset = false);
    _animateTo(Offset(_savedX, _pos!.dy));
  }

  void _onPanStart() {
    _idle?.cancel();

    _anim.stop();
    if (_inset) {
      setState(() {
        _inset = false;
        _snapping = false;
        _pos = Offset(_savedX, _pos!.dy);
      });
      return;
    }
    if (_snapping) setState(() => _snapping = false);
  }

  void _onPanUpdate(Offset delta) {
    if (_pos == null || _area == Size.zero) return;
    _userMoved = true;
    setState(() => _pos = _clampDrag(_pos! + delta));
  }

  void _onPanEnd() {
    if (_pos == null || _area == Size.zero) return;
    final Offset p = _pos!;
    final double targetX = _dockedX(_isLeftSide(p));

    setState(() => _snapping = true);
    _holdRect?.cancel();
    if ((targetX - p.dx).abs() < 1.0) {
      _anim.value = 0;
      _holdRect = Timer(const Duration(milliseconds: 260), () {
        if (mounted && _snapping) setState(() => _snapping = false);
      });
      return;
    }
    _animateTo(Offset(targetX, p.dy));
  }

  void _onTap() {
    _idle?.cancel();
    if (_inset) {
      _restore();
      return;
    }
    _scheduleIdle();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        _area = Size(c.maxWidth, c.maxHeight);

        _syncInitial(MediaQuery.of(ctx).size.height);

        final Offset p = _pos ?? Offset(_maxX, _maxY);
        if (!_started) {
          _started = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleIdle();
          });
        }
        final bool rect = _isRect;
        return Stack(

          clipBehavior: Clip.hardEdge,
          children: <Widget>[

            if (_inset)
              Positioned(
                left: _isLeftSide(p) ? 0 : null,
                right: _isLeftSide(p) ? null : 0,
                top: p.dy - 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onTap,
                  child: SizedBox(
                    width: af(context, 88),
                    height: widget.height + 48,
                  ),
                ),
              ),
            Positioned(
              left: p.dx,
              top: p.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                onPanStart: (_) => _onPanStart(),
                onPanUpdate: (DragUpdateDetails d) => _onPanUpdate(d.delta),
                onPanEnd: (_) => _onPanEnd(),

                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: rect ? 1 : 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  builder: (BuildContext ctx, double t, Widget? child) {
                    final double w = lerpDouble(_diameter, widget.width, t)!;
                    final double r = lerpDouble(_diameter / 2, widget.radius, t)!;

                    return Transform.translate(
                      offset: Offset((widget.width - w) / 2, 0),
                      child: Material(

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r),
                        ),
                        color: cs.primaryContainer,
                        elevation: 4,
                        child: SizedBox(
                          width: w,
                          height: widget.height,
                          child: Icon(widget.icon,
                              size: af(context, 24), color: cs.onPrimaryContainer),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
