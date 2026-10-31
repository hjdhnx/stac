import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:stac/src/framework/framework.dart';
import 'package:stac_core/stac_core.dart';

/// 滚动容器的共享宿主：控制器所有权 + `scrollTo` 指令 + `onScroll` 节流上报。
///
/// 三件事必须落在同一处，否则互相覆盖：
/// - **控制器**：在 build 里 new 会每次重建都回顶，且永不 dispose；
/// - **`scrollTo`**：值或 `scrollToToken` 变化时滚到目标（超出上限自动钳制）；
/// - **`onScroll`**：按 `scrollThrottleMs` 节流派发，保留原 `args` 并注入
///   `offset` / `max` / `viewport`。
///
/// 位置保持靠调用方把 [storageKeyOf] 传给 ScrollView 的 `key`：Flutter 的
/// `ScrollPosition` 只在祖先链上存在 `PageStorageKey` 时才读写偏移。
class StacScrollHost extends StatefulWidget {
  const StacScrollHost({
    super.key,
    required this.storageKey,
    required this.initialOffset,
    required this.scrollTo,
    required this.scrollToToken,
    required this.onScroll,
    required this.throttleMs,
    required this.builder,
  });

  /// 滚动位置保持键（`PageStorageKey` 的字符串值）。
  final String? storageKey;

  /// 初始偏移：仅在没有可恢复的 PageStorage 状态时生效。
  final double? initialOffset;

  /// 目标偏移：值变化时执行。
  final double? scrollTo;

  /// [scrollTo] 的重复触发令牌。
  final String? scrollToToken;

  /// 滚动回调动作。
  final StacAction? onScroll;

  /// 节流窗口（毫秒），null → [defaultThrottleMs]。
  final int? throttleMs;

  /// 拿到跨帧存活的控制器后构建滚动视图。
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// `onScroll` 默认节流窗口。
  static const int defaultThrottleMs = 100;

  /// 把 JSON 的字符串 key 转成 Flutter 的 `PageStorageKey`（空值 = 不保持）。
  static Key? storageKeyOf(String? value) =>
      value == null || value.isEmpty ? null : PageStorageKey<String>(value);

  @override
  State<StacScrollHost> createState() => _StacScrollHostState();
}

class _StacScrollHostState extends State<StacScrollHost> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: widget.scrollTo ?? widget.initialOffset ?? 0,
  );

  Timer? _throttle;
  bool _postFrameScheduled = false;
  double? _pendingTarget;

  @override
  void didUpdateWidget(covariant StacScrollHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.scrollTo ?? widget.initialOffset;
    if (target == null) return;
    final oldTarget = oldWidget.scrollTo ?? oldWidget.initialOffset;
    // 偏移没变也可能要求重滚（回顶按钮连点）：靠 token 区分。
    final tokenChanged = oldWidget.scrollToToken != widget.scrollToToken;
    if (target != oldTarget || (widget.scrollTo != null && tokenChanged)) {
      _scrollTo(target);
    }
  }

  void _scrollTo(double target) {
    if (_controller.hasClients) {
      _animateTo(target);
      return;
    }
    // 首次挂载时控制器还没有 position：等这一帧布局完再滚。
    _pendingTarget = target;
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      final pending = _pendingTarget;
      _pendingTarget = null;
      if (!mounted || pending == null || !_controller.hasClients) return;
      _animateTo(pending);
    });
  }

  void _animateTo(double target) {
    final position = _controller.position;
    final clamped = target.clamp(0.0, position.maxScrollExtent);
    if ((position.pixels - clamped).abs() < 0.5) return;
    _controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  bool _onNotification(ScrollNotification notification) {
    // depth != 0 是嵌套滚动容器（横向轮播等），只报最外层。
    if (notification.depth == 0) _scheduleReport();
    return false;
  }

  void _scheduleReport() {
    if (widget.onScroll == null || _throttle != null) return;
    _throttle = Timer(
      Duration(milliseconds: widget.throttleMs ?? StacScrollHost.defaultThrottleMs),
      _flushReport,
    );
  }

  void _flushReport() {
    _throttle = null;
    final action = widget.onScroll;
    if (!mounted || action == null || !_controller.hasClients) return;
    final position = _controller.position;
    final json = Map<String, dynamic>.from(action.toJson());
    final rawArgs = json['args'];
    final args = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : <String, dynamic>{};
    args['offset'] = position.pixels;
    args['max'] = position.maxScrollExtent;
    args['viewport'] = position.viewportDimension;
    json['args'] = args;
    final result = Stac.onCallFromJson(json, context);
    if (result is Future) unawaited(result.catchError((Object _) => null));
  }

  @override
  void dispose() {
    _throttle?.cancel();
    _throttle = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: widget.builder(context, _controller),
      );
}
