import 'package:json_annotation/json_annotation.dart';
import 'package:stac_core/core/converters/double_converter.dart';
import 'package:stac_core/core/stac_widget.dart';
import 'package:stac_core/foundation/text/stac_text_style/stac_text_style.dart';

part 'stac_marquee_text.g.dart';

/// 单行跑马灯文本（DsPlayer `MarqueeText` 的 stac 化）。
///
/// 只在文本**溢出**可用宽度时滚动；未溢出 = 普通静态文本（零动画开销）。
/// 剧本 / 片名这类长标题在网格卡里被截断成「令人心动的offer 第…」，
/// 滚动一遍才能读全名——这是 DsPlayer 外观页「剧名跑马灯」开关的落点。
///
/// JSON 示例：
/// ```json
/// {"type":"marqueeText","data":"{{vodName}}",
///  "style":{"fontSize":12,"fontWeight":"w500"},"enabled":true,"speed":30}
/// ```
@JsonSerializable()
class StacMarqueeText extends StacWidget {
  const StacMarqueeText({
    required this.data,
    this.style,
    this.speed,
    this.gap,
    this.enabled,
    this.maxLines,
  });

  /// 文本内容（纯文本；跑马灯路径不渲染富文本高亮）。
  final String data;

  /// 文本样式（复用 text 的 StacTextStyle）。
  final StacTextStyle? style;

  /// 滚动速度（逻辑像素/秒），缺省 30（DsPlayer 同值）。
  @DoubleConverter()
  final double? speed;

  /// 循环首尾间距（逻辑像素），缺省 24。
  @DoubleConverter()
  final double? gap;

  /// false = 退化为静态截断文本（调用方按场景关闭，如搜索结果卡）。
  final bool? enabled;

  /// 静态路径的最大行数，缺省 1。
  final int? maxLines;

  @override
  String get type => 'marqueeText';

  factory StacMarqueeText.fromJson(Map<String, dynamic> json) =>
      _$StacMarqueeTextFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$StacMarqueeTextToJson(this);
}
