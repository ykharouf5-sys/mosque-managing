import 'package:flutter/widgets.dart';

/// Shared by the root navigator and data-refreshing screens.
final refreshRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Reports foreground + top-route + selected-tab visibility without changing
/// layout. Native/network services stay outside this preview-safe widget.
class RefreshVisibility extends StatefulWidget {
  const RefreshVisibility({
    super.key,
    this.active = true,
    required this.onChanged,
    required this.child,
  });

  final bool active;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<RefreshVisibility> createState() => _RefreshVisibilityState();
}

class _RefreshVisibilityState extends State<RefreshVisibility>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  bool _foreground = true;
  bool _topRoute = true;
  bool? _reported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      refreshRouteObserver.unsubscribe(this);
      _route = route;
      _topRoute = route?.isCurrent ?? true;
      if (route != null) refreshRouteObserver.subscribe(this, route);
    }
    _report();
  }

  @override
  void didUpdateWidget(RefreshVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    _report();
  }

  void _report() {
    // Defer notifications to avoid changing Riverpod during a widget build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publish();
    });
  }

  void _publish() {
    final visible = _foreground && _topRoute && widget.active;
    if (_reported == visible) return;
    _reported = visible;
    widget.onChanged(visible);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Paused apps stop receiving frames. Waiting for a post-frame callback
    // would leave timers running until resume, exactly what we must prevent.
    _publish();
  }

  @override
  void didPush() {
    _topRoute = true;
    _report();
  }

  @override
  void didPushNext() {
    _topRoute = false;
    _report();
  }

  @override
  void didPopNext() {
    _topRoute = true;
    _report();
  }

  @override
  void didPop() {
    _topRoute = false;
    _report();
  }

  @override
  void dispose() {
    refreshRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    // Owners cancel timers/release view registrations in their own dispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
