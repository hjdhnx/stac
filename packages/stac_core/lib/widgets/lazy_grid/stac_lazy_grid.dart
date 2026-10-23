import 'package:json_annotation/json_annotation.dart';
import 'package:stac_core/core/converters/double_converter.dart';
import 'package:stac_core/core/stac_action.dart';
import 'package:stac_core/core/stac_widget.dart';
import 'package:stac_core/foundation/foundation.dart';

part 'stac_lazy_grid.g.dart';

/// A data-driven, lazily built grid.
///
/// Unlike `gridView`, which requires every child to be a full Stac model,
/// `lazyGrid` takes plain data items plus a single `itemTemplate`. The
/// template is cloned per item with `{{key}}` placeholders replaced by the
/// corresponding item field, so a 500-item list ships only its data.
///
/// JSON:
/// ```json
/// {
///   "type": "lazyGrid",
///   "crossAxisCount": 3,
///   "items": [{"id": "1", "title": "A"}],
///   "itemTemplate": {"type": "text", "data": "{{title}}"},
///   "hasMore": true,
///   "onEndReached": {"actionType": "js.call", "action": "more"}
/// }
/// ```
@JsonSerializable()
class StacLazyGrid extends StacWidget {
  const StacLazyGrid({
    this.crossAxisCount,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.padding,
    this.header,
    this.footer,
    this.items,
    this.itemTemplate,
    this.empty,
    this.hasMore,
    this.loadingMore,
    this.onEndReached,
    this.endReachedThreshold,
  });

  final int? crossAxisCount;

  @DoubleConverter()
  final double? mainAxisSpacing;

  @DoubleConverter()
  final double? crossAxisSpacing;

  @DoubleConverter()
  final double? childAspectRatio;

  @DoubleConverter()
  final double? mainAxisExtent;

  final StacEdgeInsets? padding;

  /// Rendered above the grid (scrolls with it).
  final StacWidget? header;

  /// Rendered below the grid (scrolls with it).
  final StacWidget? footer;

  /// Flat data rows; each row is a map of placeholder values.
  final List<dynamic>? items;

  /// Widget tree cloned per item; string values may contain `{{key}}`.
  final StacWidget? itemTemplate;

  /// Shown instead of the grid when [items] is empty.
  final StacWidget? empty;

  /// When true and the user scrolls near the end, [onEndReached] fires.
  final bool? hasMore;

  /// Shows a footer spinner; also suppresses repeated [onEndReached] calls.
  final bool? loadingMore;

  final StacAction? onEndReached;

  /// Distance from the bottom, in logical pixels, that triggers
  /// [onEndReached]. Defaults to 320.
  @DoubleConverter()
  final double? endReachedThreshold;

  factory StacLazyGrid.fromJson(Map<String, dynamic> json) =>
      _$StacLazyGridFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$StacLazyGridToJson(this);
}
