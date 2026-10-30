import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:stac/src/parsers/core/stac_widget_parser.dart';
import 'package:stac/src/parsers/foundation/geometry/stac_edge_insets_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_drag_start_behavior_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_scroll_physics_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_scroll_view_keyboard_dismiss_behavior_parser.dart';
import 'package:stac/src/parsers/foundation/layout/stac_axis_parser.dart';
import 'package:stac/src/parsers/foundation/layout/stac_clip_parser.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

class StacListViewParser extends StacParser<StacListView> {
  const StacListViewParser({this.controller});

  final ScrollController? controller;

  @override
  String get type => WidgetType.listView.name;

  @override
  StacListView getModel(Map<String, dynamic> json) =>
      StacListView.fromJson(json);

  @override
  Widget parse(BuildContext context, StacListView model) {
    // 初始偏移：需要一个**跨帧存活的** ScrollController（在 build 里 new 一个
    // 会每次重建都回到起点，且永不 dispose），所以套一层 StatefulWidget。
    if (controller == null && model.initialScrollOffset != null) {
      return _InitialOffsetList(
        offset: model.initialScrollOffset!,
        builder: (c) => _buildList(context, model, c),
      );
    }
    return _buildList(context, model, controller);
  }

  Widget _buildList(
    BuildContext context,
    StacListView model,
    ScrollController? controller,
  ) {
    return ListView.separated(
      scrollDirection: model.scrollDirection?.parse ?? Axis.vertical,
      reverse: model.reverse ?? false,
      controller: controller,
      primary: controller == null ? model.primary : false,
      physics: model.physics?.parse,
      shrinkWrap: model.shrinkWrap ?? false,
      padding: model.padding?.parse,
      addAutomaticKeepAlives: model.addAutomaticKeepAlives ?? true,
      addRepaintBoundaries: model.addRepaintBoundaries ?? true,
      addSemanticIndexes: model.addSemanticIndexes ?? true,
      scrollCacheExtent: model.cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(model.cacheExtent!),
      dragStartBehavior:
          model.dragStartBehavior?.parse ?? DragStartBehavior.start,
      keyboardDismissBehavior:
          model.keyboardDismissBehavior?.parse ??
          ScrollViewKeyboardDismissBehavior.manual,
      restorationId: model.restorationId,
      clipBehavior: model.clipBehavior?.parse ?? Clip.hardEdge,
      itemCount: model.children?.length ?? 0,
      itemBuilder: (context, index) {
        if (model.children == null || model.children!.isEmpty) {
          return const SizedBox();
        }
        // Parse in the item's own element, so theme colors and text styles
        // resolved while parsing update when the theme changes.
        return Builder(
          builder: (context) =>
              model.children![index].parse(context) ?? const SizedBox(),
        );
      },
      separatorBuilder: (context, _) => Builder(
        builder: (context) =>
            model.separator.parse(context) ?? const SizedBox(),
      ),
    );
  }
}

/// 带初始偏移的列表：控制器必须跨帧存活（在 build 里 new 会每帧回到起点，
/// 且没有机会 dispose）。
class _InitialOffsetList extends StatefulWidget {
  const _InitialOffsetList({required this.offset, required this.builder});

  final double offset;
  final Widget Function(ScrollController controller) builder;

  @override
  State<_InitialOffsetList> createState() => _InitialOffsetListState();
}

class _InitialOffsetListState extends State<_InitialOffsetList> {
  late ScrollController _controller = ScrollController(
    initialScrollOffset: widget.offset,
  );

  @override
  void didUpdateWidget(_InitialOffsetList old) {
    super.didUpdateWidget(old);
    // 偏移变了（换了选中项）→ 平滑滚到新位置；控制器本身复用，scroll 位置不丢。
    if (old.offset != widget.offset && _controller.hasClients) {
      _controller.animateTo(
        widget.offset.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
