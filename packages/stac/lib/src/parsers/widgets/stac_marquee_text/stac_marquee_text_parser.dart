import 'dart:math' as math;

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

  final ScrollController _scroll = ScrollController();
  AnimationController? _controller;
  double _distance = 0;
  double _textWidth = -1;
  double _measuredMaxWidth = -1;
  String _measuredData = '';

  @override
  void dispose() {
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _measure(BuildContext context, TextStyle style, double maxWidth) {
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
  }

  /// 单条循环：0 → 起点停留 → 匀速滚到尾部 → 尾部停留。
  void _ensureController(double distance) {
    if (_controller != null && (_distance - distance).abs() < 0.5) return;
    _controller?.dispose();
    _distance = distance;
    final scrollMs = math.max(400, (distance / math.max(1, widget.speed) * 1000).round());
    final totalMs = _startHold.inMilliseconds + scrollMs + _endHold.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..addListener(_syncScroll);
    _controller!.repeat();
  }

  void _syncScroll() {
    final c = _controller;
    if (c == null || !_scroll.hasClients) return;
    final target = -_translateFor(c.value);
    if ((_scroll.offset - target).abs() > 0.5) _scroll.jumpTo(target);
  }

  double _translateFor(double value) {
    final totalMs = _controller!.duration!.inMilliseconds.toDouble();
    final t = value * totalMs;
    final startMs = _startHold.inMilliseconds.toDouble();
    final scrollMs =
        math.max(1.0, totalMs - startMs - _endHold.inMilliseconds).toDouble();
    if (t <= startMs) return 0;
    if (t >= startMs + scrollMs) return -_distance;
    return -_distance * ((t - startMs) / scrollMs);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    // ponytail: 没有 DsPlayer 的「滚动中静默 + 测量 LRU」。同屏滚动中的
    // 卡片最多十几张，每张只重绘自己的 Transform 层；要做优化再补这两层。
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
          _controller?.stop();
          if (_scroll.hasClients) _scroll.jumpTo(0);
          return Text(
            widget.data,
            style: style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        }
        _ensureController(_textWidth + widget.gap);
        // 滚动容器用横向 ScrollView（禁掉手势）：它给子节点**无界宽度**且自带
        // 裁剪，不会像 Row+OverflowBox 那样在有限宽/无界高约束下抛
        // 「infinite size during layout」（真机实锤：整格空白 + 黄色溢出条）。
        return SingleChildScrollView(
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
        );
      },
    );
  }
}
