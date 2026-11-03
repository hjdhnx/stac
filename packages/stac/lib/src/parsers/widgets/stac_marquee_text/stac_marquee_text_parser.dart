import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker, SchedulerBinding;
import 'package:material_ui/material_ui.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_style_parser.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

/// `marqueeText`：单行跑马灯（DsPlayer `MarqueeText` 的 stac 版本）。
///
/// 只在文本**溢出**可用宽度时滚动。未溢出 / `enabled == false` → 普通静态
/// 截断文本，不建动画（零 ticker、零重绘）。滚动节奏照抄 DsPlayer：
/// 起点停 600ms → 匀速（默认 30px/s）滚到尾部 → 停 1200ms → 回到起点循环。
class StacMarqueeTextParser extends StacParser<StacMarqueeText> {
  const StacMarqueeTextParser();

  /// 测试接缝：清模块级「上次竖直滚动」（跨用例静态污染）。
  static void debugResetScrollActivity() =>
      _MarqueeTextState._debugResetScrollActivity();

  @override
  String get type => 'marqueeText';

  @override
  StacMarqueeText getModel(Map<String, dynamic> json) =>
      StacMarqueeText.fromJson(json);

  @override
  Widget parse(BuildContext context, StacMarqueeText model) {
    return _MarqueeText(
      data: model.data,
      style: model.style?.parse(context),
      speed: model.speed ?? 30,
      gap: model.gap ?? 24,
      enabled: model.enabled ?? true,
      maxLines: model.maxLines ?? 1,
    );
  }
}

class _MarqueeText extends StatefulWidget {
  const _MarqueeText({
    required this.data,
    required this.style,
    required this.speed,
    required this.gap,
    required this.enabled,
    required this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final double speed;
  final double gap;
  final bool enabled;
  final int maxLines;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  static const Duration _startHold = Duration(milliseconds: 600);
  static const Duration _endHold = Duration(milliseconds: 1200);

  /// C-06：竖直滚动后冻结相位的时间窗（毫秒）。
  static const int _scrollFreezeMs = 300;

  /// 上次竖直滚动活动（模块级：所有跑马灯共享同一次列表滚动）。
  static int _lastScrollActivityMs = -100000;

  /// 测试接缝：清模块级滚动活动（跨用例静态污染）。
  static void _debugResetScrollActivity() {
    _lastScrollActivityMs = -100000;
  }

  /// 宽度测量 LRU（text+style+scaler+maxWidth → 文本宽），上限 128。
  static final Map<String, double> _measureLru = <String, double>{};
  static const int _measureLruMax = 128;

  final ScrollController _scroll = ScrollController();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _pendingMs = 0;
  double _clockMs = 0;
  double _distance = 0;
  double _textWidth = -1;
  double _measuredMaxWidth = -1;
  String _measuredData = '';
  bool _visible = true;
  ScrollPosition? _ancestorPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindAncestorScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindAncestorScroll();
  }

  @override
  void dispose() {
    _ancestorPos?.removeListener(_onAncestorScroll);
    _ticker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 绑定最近的竖直祖先滚动（卡片所在列表），用于「滚动中静默」。
  void _bindAncestorScroll() {
    ScrollPosition? pos;
    try {
      pos = Scrollable.maybeOf(context)?.position;
    } catch (_) {
      pos = null;
    }
    if (identical(pos, _ancestorPos)) return;
    _ancestorPos?.removeListener(_onAncestorScroll);
    _ancestorPos = pos;
    _ancestorPos?.addListener(_onAncestorScroll);
  }

  void _onAncestorScroll() {
    _lastScrollActivityMs =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMilliseconds;
    // 滚动结束/过程中都重估可见性（滚出视口停 ticker）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisible();
    });
  }

  bool get _scrollFrozen {
    // 负差值（时间戳回绕/测试重置）视为未冻结 —— 否则静态标记会把后续
    // 帧永远卡在冻结态（widget 测试跨用例实锤）。
    final diff =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMilliseconds -
            _lastScrollActivityMs;
    return diff >= 0 && diff < _scrollFreezeMs;
  }

  void _measure(BuildContext context, TextStyle style, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context).toString();
    final key = '${widget.data}\u0000${style.toString()}\u0000$scaler\u0000$maxWidth';
    final cached = _measureLru[key];
    if (cached != null) {
      _measureLru.remove(key);
      _measureLru[key] = cached; // LRU 提升
      _textWidth = cached;
      _measuredMaxWidth = maxWidth;
      _measuredData = widget.data;
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.data, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    _textWidth = painter.width;
    painter.dispose();
    _measuredMaxWidth = maxWidth;
    _measuredData = widget.data;
    _measureLru[key] = _textWidth;
    if (_measureLru.length > _measureLruMax) {
      _measureLru.remove(_measureLru.keys.first);
    }
  }

  double get _totalMs =>
      _startHold.inMilliseconds + _scrollMs + _endHold.inMilliseconds;

  double get _scrollMs =>
      math.max(400.0, _distance / math.max(1, widget.speed) * 1000);

  /// 相位机：hold(600) → 匀速滚动 → 尾部 hold(1200) → 循环。
  double _translateFor(double clockMs) {
    final t = clockMs % _totalMs;
    final startMs = _startHold.inMilliseconds.toDouble();
    final scrollMs = _scrollMs.toDouble();
    if (t <= startMs) return 0;
    if (t >= startMs + scrollMs) return -_distance;
    return -_distance * ((t - startMs) / scrollMs);
  }

  void _startTicker() {
    if (_ticker == null) {
      _ticker = createTicker(_onTick);
      _lastTick = Duration.zero;
      _pendingMs = 0;
      _clockMs = 0;
    }
    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastTick).inMilliseconds.toDouble();
    _lastTick = elapsed;
    if (dtMs <= 0) return;
    // C-06：竖直滚动 300ms 内冻结相位（指针还在滑，画面不动）
    if (_scrollFrozen) {
      _pendingMs = 0;
      return;
    }
    // dt<33ms 累计，到阈值再一次性位移（30fps 上限，省小步重绘）
    _pendingMs += dtMs;
    if (_pendingMs < 33) return;
    final step = _pendingMs;
    _pendingMs = 0;
    _clockMs += step;
    if (!_scroll.hasClients) return;
    final target = -_translateFor(_clockMs);
    if ((_scroll.offset - target).abs() > 0.5) _scroll.jumpTo(target);
  }

  /// 视口可见性（ScrollEnd 后重估）：不可见停 ticker，恢复可见从头续滚。
  void _checkVisible() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    final media = MediaQuery.maybeOf(context);
    final screen = Offset.zero & (media?.size ?? box.size);
    final visible = rect.overlaps(screen);
    if (visible == _visible) return;
    _visible = visible;
    if (!_visible) {
      _ticker?.stop();
    } else {
      _clockMs = 0;
      _pendingMs = 0;
      _startTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (_measuredData != widget.data ||
            _measuredMaxWidth != maxWidth ||
            _textWidth < 0) {
          _measure(context, style, maxWidth);
        }
        final needScroll = widget.enabled &&
            maxWidth.isFinite &&
            _textWidth > maxWidth + 0.5;
        if (!needScroll) {
          _ticker?.stop();
          if (_scroll.hasClients) _scroll.jumpTo(0);
          return Text(
            widget.data,
            style: style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        }
        _distance = _textWidth + widget.gap;
        if (_visible) _startTicker();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkVisible();
        });
        // 自己的横向 jumpTo 通知就地吞掉，不冒泡喂祖先的触底闸门。
        return NotificationListener<ScrollNotification>(
          onNotification: (n) => true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            controller: _scroll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.data,
                  style: style,
                  maxLines: widget.maxLines,
                  softWrap: false,
                ),
                SizedBox(width: widget.gap),
              ],
            ),
          ),
        );
      },
    );
  }
}
