import 'dart:async';

import 'package:flutter/material.dart';

const Duration kPollInterval = Duration(seconds: 3);

final RouteObserver<ModalRoute<dynamic>> autoRefreshRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class AutoRefresh extends StatefulWidget {
  const AutoRefresh({
    super.key,
    required this.onTick,
    this.interval = kPollInterval,
    this.enabled = true,
    this.immediate = true,
    this.child,
  });

  final Future<void> Function() onTick;

  final Duration interval;

  final bool enabled;

  final bool immediate;

  final Widget? child;

  @override
  State<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends State<AutoRefresh>
    with WidgetsBindingObserver, RouteAware {
  Timer? _timer;

  bool _inFlight = false;

  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restart();

    if (widget.immediate && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tick(force: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      if (_route != null) autoRefreshRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) {
        autoRefreshRouteObserver.subscribe(this, route);
      }
    }
  }

  @override
  void didUpdateWidget(AutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.interval != widget.interval) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.enabled) return;

      _restart();
      if (widget.immediate) _tick(force: true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didPopNext() {
    if (!widget.enabled) return;
    if (widget.immediate) _tick(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();

    if (_route != null) autoRefreshRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!widget.enabled) return;
    _timer = Timer.periodic(widget.interval, (_) => _tick());
  }

  Future<void> _tick({bool force = false}) async {
    if (!mounted || _inFlight) return;

    if (!force) {
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
    }
    _inFlight = true;
    try {
      await widget.onTick();
    } catch (_) {
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
