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
import 'package:stac/src/utils/stac_scroll_host.dart';
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
    // 初始偏移 / 定位指令 / 滚动上报都需要一个**跨帧存活的** ScrollController
    // （在 build 里 new 一个会每次重建都回到起点，且永不 dispose）。
    final needsHost = controller == null &&
        (model.initialScrollOffset != null ||
            model.scrollTo != null ||
            model.onScroll != null);
    if (needsHost) {
      return StacScrollHost(
        storageKey: model.key,
        initialOffset: model.initialScrollOffset,
        scrollTo: model.scrollTo,
        scrollToToken: model.scrollToToken,
        onScroll: model.onScroll,
        throttleMs: model.scrollThrottleMs,
        builder: (c, scrollController) =>
            _buildList(context, model, scrollController),
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
      key: StacScrollHost.storageKeyOf(model.key),
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
