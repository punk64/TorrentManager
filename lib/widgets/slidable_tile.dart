import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';






class SlidableActionItem {
  const SlidableActionItem({
    required this.icon,
    required this.onPressed,
    this.badgeColor,
    this.foregroundColor = Colors.white,
    this.flex = 1,
    this.iconSize = 18,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;

  
  final Color? badgeColor;

  final Color foregroundColor;

  
  final int flex;

  final double iconSize;

  final String? tooltip;
}






enum SlidableMotionKind {
  
  scroll,

  
  behind,
}








class SlidableAutoCloseGroup extends StatefulWidget {
  const SlidableAutoCloseGroup({super.key, required this.child});

  final Widget child;

  static SlidableAutoCloseGroupState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SlidableAutoCloseScope>()
      ?.state;

  @override
  State<SlidableAutoCloseGroup> createState() =>
      SlidableAutoCloseGroupState();
}

class SlidableAutoCloseGroupState extends State<SlidableAutoCloseGroup> {
  final Set<_SlidableTileState> _members = <_SlidableTileState>{};

  void _register(_SlidableTileState tile) => _members.add(tile);

  void _unregister(_SlidableTileState tile) => _members.remove(tile);

  void _closeOthers(_SlidableTileState keep) {
    for (final _SlidableTileState t in _members.toList()) {
      if (!identical(t, keep)) t.close();
    }
  }

  void _closeAll() {
    for (final _SlidableTileState t in _members.toList()) {
      t.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SlidableAutoCloseScope(
      state: this,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (ScrollStartNotification n) {
          if (n.dragDetails != null) _closeAll();
          return false;
        },
        child: widget.child,
      ),
    );
  }
}

class _SlidableAutoCloseScope extends InheritedWidget {
  const _SlidableAutoCloseScope({required this.state, required super.child});

  final SlidableAutoCloseGroupState state;

  @override
  bool updateShouldNotify(_SlidableAutoCloseScope oldWidget) => false;
}










class SlidableTile extends StatefulWidget {
  const SlidableTile({
    super.key,
    required this.child,
    this.startActions = const <SlidableActionItem>[],
    this.endActions = const <SlidableActionItem>[],
    this.extentRatio = 0.17,
    this.slotCount,
    this.dragResistance = defaultDragResistance,
    this.motion = SlidableMotionKind.scroll,
    this.enabled = true,
    this.onLongPress,
    this.onTap,
    this.onSlideChanged,
    this.borderRadius,
    this.contentBackground,
    this.margin,
  });

  final Widget child;

  
  
  
  
  
  final EdgeInsetsGeometry? margin;

  
  final List<SlidableActionItem> startActions;

  
  final List<SlidableActionItem> endActions;

  
  
  
  
  final VoidCallback? onLongPress;

  
  
  
  
  
  
  
  
  
  
  final VoidCallback? onTap;

  
  
  
  
  
  final ValueChanged<bool>? onSlideChanged;

  
  
  final double extentRatio;

  
  
  
  
  
  
  
  
  final int? slotCount;

  
  
  
  
  
  
  final double dragResistance;

  final SlidableMotionKind motion;

  final bool enabled;

  
  final BorderRadius? borderRadius;

  
  
  
  
  final Color? contentBackground;

  
  
  
  
  
  
  static const double defaultDragResistance = 2.6;

  
  static const double flingVelocity = 300;

  
  static const double settleRatio = 0.5;

  
  
  
  
  
  
  
  
  
  static const double crossSettleRatio = 0.05;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  static double settleTarget({
    required double ratio,
    required double vx,
    required bool hasStart,
    required bool hasEnd,
    double flingVelocity = flingVelocity,
    double settleRatio = settleRatio,
    bool crossedZero = false,
    double crossSettleRatio = crossSettleRatio,
  }) {
    if (vx <= -flingVelocity && hasEnd) return 1;
    if (vx >= flingVelocity && hasStart) return -1;
    final double threshold =
        crossedZero ? crossSettleRatio.abs() : settleRatio.abs();
    if (ratio <= -threshold && hasStart) return -1;
    if (ratio >= threshold && hasEnd) return 1;
    return 0;
  }

  @override
  State<SlidableTile> createState() => _SlidableTileState();
}






final Set<_SlidableTileState> _liveSlidables = <_SlidableTileState>{};





void closeAllSlidables() {
  for (final _SlidableTileState t in _liveSlidables.toList()) {
    t.close();
  }
}


bool hasOpenSlidable() {
  for (final _SlidableTileState t in _liveSlidables.toList()) {
    if (t.isOpen) return true;
  }
  return false;
}

class _SlidableTileState extends State<SlidableTile>
    with SingleTickerProviderStateMixin {
  
  
  
  
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this);

  SlidableAutoCloseGroupState? _group;
  double _width = 0;

  
  bool _crossedZero = false;

  
  
  
  
  
  double _originRatio = 0;

  
  int _lastSign = 0;

  
  static const double _flingRatioCap = 8;

  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.9);

  bool get _hasStart => widget.startActions.isNotEmpty;
  bool get _hasEnd => widget.endActions.isNotEmpty;

  double get _startExtent => _hasStart ? _width * widget.extentRatio : 0;
  double get _endExtent => _hasEnd ? _width * widget.extentRatio : 0;

  double get _ratio => _controller.value.clamp(-1.0, 1.0);

  
  bool get isOpen => _controller.value.abs() > 0.001;

  
  bool _reportedOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_notifySlide);
    _liveSlidables.add(this);
  }

  
  void _notifySlide() {
    final bool open = isOpen;
    if (open == _reportedOpen) return;
    _reportedOpen = open;
    widget.onSlideChanged?.call(open);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SlidableAutoCloseGroupState? g =
        SlidableAutoCloseGroup.maybeOf(context);
    if (!identical(g, _group)) {
      _group?._unregister(this);
      _group = g;
      _group?._register(this);
    }
  }

  @override
  void dispose() {
    _liveSlidables.remove(this);
    _group?._unregister(this);
    _controller.dispose();
    super.dispose();
  }

  
  void close() {
    if (!mounted || _controller.value == 0) return;
    _animateTo(0);
  }

  void _animateTo(double target, [double velocity = 0]) {
    if (!mounted) return;
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, target, velocity),
    );
  }

  

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _group?._closeOthers(this);
    _controller.stop();
    _crossedZero = false;
    _originRatio = _controller.value;
    _lastSign = _controller.value.sign.toInt();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _width <= 0) return;
    final double delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    
    
    
    final double pane = delta < 0 ? _endExtent : _startExtent;
    if (pane <= 0) return;
    final double r = widget.dragResistance <= 0 ? 1.0 : widget.dragResistance;
    double next =
        (_controller.value - delta / (pane * r)).clamp(-1.0, 1.0).toDouble();

    
    
    
    
    
    if (_originRatio.abs() > 0.001) {
      next = _originRatio > 0 ? next.clamp(0.0, 1.0) : next.clamp(-1.0, 0.0);
    }
    _controller.value = next;

    
    
    final int sign = next == 0 ? _lastSign : next.sign.toInt();
    if (_lastSign != 0 && sign != 0 && sign != _lastSign) {
      _crossedZero = true;
    }
    if (sign != 0) _lastSign = sign;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled || _width <= 0) return;
    final double vx = details.velocity.pixelsPerSecond.dx;

    final double target = SlidableTile.settleTarget(
      ratio: _ratio,
      vx: vx,
      hasStart: _hasStart,
      hasEnd: _hasEnd,
      crossedZero: _crossedZero,
    );

    final double pane = target != 0
        ? (target > 0 ? _endExtent : _startExtent)
        : (vx < 0 ? _endExtent : _startExtent);
    final double r = widget.dragResistance <= 0 ? 1.0 : widget.dragResistance;
    final double vRatio = pane > 0
        ? (-vx / (pane * r)).clamp(-_flingRatioCap, _flingRatioCap).toDouble()
        : 0.0;

    
    
    final bool sameDir = (target > 0 && vRatio > 0) || (target < 0 && vRatio < 0);
    _animateTo(target, sameDir ? vRatio : 0.0);
  }

  void _handleActionTap(SlidableActionItem item) {
    close();
    item.onPressed();
  }

  

  @override
  Widget build(BuildContext context) {
    final Widget body = (!widget.enabled || (!_hasStart && !_hasEnd))
        ? widget.child
        : _buildSlidable();
    final EdgeInsetsGeometry? m = widget.margin;
    return m == null ? body : Padding(padding: m, child: body);
  }

  Widget _buildSlidable() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          
          
          
          onTap: () {
            if (_controller.value.abs() > 0.001) {
              close();
              return;
            }
            
            
            
            widget.onTap?.call();
          },
          
          
          
          
          
          onLongPress: widget.onLongPress,
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: AnimatedBuilder(
              animation: _controller,
              
              
              child: _contentLayer(),
              builder: (BuildContext context, Widget? child) {
                final double r = _ratio;
                final double contentDx =
                    r >= 0 ? -(r * _endExtent) : (-r * _startExtent);
                final bool behind = widget.motion == SlidableMotionKind.behind;
                return Stack(
                  children: <Widget>[
                    if (_hasStart)
                      _pane(
                        widget.startActions,
                        extent: _startExtent,
                        isStart: true,
                        
                        dx: behind ? 0.0 : -_startExtent + contentDx,
                      ),
                    if (_hasEnd)
                      _pane(
                        widget.endActions,
                        extent: _endExtent,
                        isStart: false,
                        dx: behind ? _width - _endExtent : _width + contentDx,
                      ),
                    Transform.translate(
                      offset: Offset(contentDx, 0),
                      
                      
                      
                      child: AbsorbPointer(
                        absorbing: r.abs() > 0.001,
                        
                        
                        
                        
                        
                        child: ClipRRect(
                          borderRadius:
                              widget.borderRadius ?? BorderRadius.zero,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _contentLayer() {
    final Color? bg = widget.contentBackground;
    
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: bg == null
          ? widget.child
          : ColoredBox(color: bg, child: widget.child),
    );
  }

  Widget _pane(
    List<SlidableActionItem> items, {
    required double extent,
    required double dx,
    required bool isStart,
  }) {
    
    
    final int want = widget.slotCount ?? items.length;
    final int slots = want < items.length ? items.length : want;
    final double slotW = extent / slots;

    return Positioned(
      left: dx,
      top: 0,
      bottom: 0,
      width: extent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        
        
        mainAxisAlignment:
            isStart ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          for (final SlidableActionItem a in items)
            SizedBox(width: slotW * a.flex, child: _actionSlot(a)),
        ],
      ),
    );
  }

  Widget _actionSlot(SlidableActionItem item) {
    final Color badge = item.badgeColor ??
        Theme.of(context).colorScheme.secondaryContainer;
    Widget slot = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleActionTap(item),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
          child: Icon(item.icon, size: item.iconSize, color: item.foregroundColor),
        ),
      ),
    );
    if (item.tooltip != null) {
      slot = Tooltip(message: item.tooltip!, child: slot);
    }
    return slot;
  }
}
