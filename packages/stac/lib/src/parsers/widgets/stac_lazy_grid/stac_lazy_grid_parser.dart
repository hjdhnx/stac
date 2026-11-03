import 'dart:async' show Timer;
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';
import 'package:stac/src/framework/framework.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/core/stac_widget_parser.dart';
import 'package:stac/src/parsers/foundation/geometry/stac_edge_insets_parser.dart';
import 'package:stac/src/utils/stac_scroll_host.dart';
import 'package:stac/src/utils/template_binder.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

/// `lazyGrid`：数据行 + 单份模板，逐项 `{{key}}` 绑定。
///
/// 用 `CustomScrollView + SliverGrid.builder` 保证**只有可见项被构建**；
/// 滚动接近底部时按 `hasMore` 触发一次 `onEndReached`（js.call），
/// 新数据到达（条目数变化）后重新武装。
class StacLazyGridParser extends StacParser<StacLazyGrid> {
  const StacLazyGridParser();

  @override
  String get type => WidgetType.lazyGrid.name;

  @override
  StacLazyGrid getModel(Map<String, dynamic> json) =>
      StacLazyGrid.fromJson(json);

  @override
  Widget parse(BuildContext context, StacLazyGrid model) {
    final template = model.itemTemplate?.toJson();
    final rows = model.items ?? const <dynamic>[];
    // 控制器、定位与上报统一由宿主持有（同 listView），位置保持靠 PageStorageKey。
    return StacScrollHost(
      storageKey: model.key,
      initialOffset: model.initialScrollOffset,
      scrollTo: model.scrollTo,
      scrollToToken: model.scrollToToken,
      onScroll: model.onScroll,
      throttleMs: model.scrollThrottleMs,
      builder: (c, controller) {
        if (template == null || rows.isEmpty) {
          // 空态也要保留 header/footer：筛选条在 header 里，否则用户无法切回有数据的分类。
          return CustomScrollView(
            key: StacScrollHost.storageKeyOf(model.key),
            controller: controller,
            scrollCacheExtent: model.cacheExtent == null
                ? null
                : ScrollCacheExtent.pixels(model.cacheExtent!),
            slivers: [
              if (model.header != null)
                SliverToBoxAdapter(
                  child:
                      model.header!.parse(context) ?? const SizedBox.shrink(),
                ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: model.empty?.parse(context) ?? const SizedBox.shrink(),
              ),
            ],
          );
        }
        return _LazyGridScroll(
          model: model,
          template: template,
          rows: rows,
          controller: controller,
        );
      },
    );
  }
}

class _LazyGridScroll extends StatefulWidget {
  const _LazyGridScroll({
    required this.model,
    required this.template,
    required this.rows,
    required this.controller,
  });

  final StacLazyGrid model;
  final Map<String, dynamic> template;
  final List<dynamic> rows;

  /// 由 [StacScrollHost] 持有（跨帧存活、统一节流上报）。
  final ScrollController controller;

  @override
  State<_LazyGridScroll> createState() => _LazyGridScrollState();
}

class _LazyGridScrollState extends State<_LazyGridScroll> {
  bool _armed = true;

  /// 触底**停稳**判定（PLAN-NEXT N10-03）：滚到底部后再等 300ms 没有新滚动
  /// 才真的拉下一页。
  ///
  /// 为什么需要：飞滑到底时 `_onScroll` 会在同一帧内命中阈值，此时用户还在
  /// 惯性滚动、离真正到底还有几百像素 —— 立刻发 onEndReached 会让后续帧
  /// 继续越界（列表抖动 + 一次滑动连发多次请求）。DsPlayer `paged.dart:315`
  /// 是同一做法（停稳 300ms 再触发）。
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _LazyGridScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    // 新数据到达（条目数变化）后才允许再次触发，避免滚动抖动里连发。
    if (oldWidget.rows.length != widget.rows.length) _armed = true;
  }

  void _onScroll() {
    final m = widget.model;
    if (!_armed || m.hasMore != true || m.loadingMore == true) return;
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final threshold = m.endReachedThreshold ?? 320;
    if (pos.pixels < pos.maxScrollExtent - threshold) {
      // 离开触底区：撤销待触发的停稳判定
      _settle?.cancel();
      _settle = null;
      return;
    }
    // 触底：等 300ms 没有新滚动再触发（连续滚动会不断重置定时器）
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_armed || m.hasMore != true || m.loadingMore == true) return;
      if (!widget.controller.hasClients) return;
      final p2 = widget.controller.position;
      if (p2.pixels < p2.maxScrollExtent - threshold) return;
      _armed = false;
      m.onEndReached?.parse(context);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final padding = m.padding?.parse ?? EdgeInsets.zero;
    final rows = widget.rows;

    return CustomScrollView(
      key: StacScrollHost.storageKeyOf(m.key),
      controller: widget.controller,
      scrollCacheExtent: m.cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(m.cacheExtent!),
      slivers: [
        if (m.header != null)
          SliverToBoxAdapter(
            child: m.header!.parse(context) ?? const SizedBox.shrink(),
          ),
        SliverPadding(
          padding: padding,
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: m.crossAxisCount ?? 2,
              mainAxisSpacing: m.mainAxisSpacing ?? 0,
              crossAxisSpacing: m.crossAxisSpacing ?? 0,
              childAspectRatio: m.childAspectRatio ?? 1,
              mainAxisExtent: m.mainAxisExtent,
            ),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is! Map) return const SizedBox.shrink();
              // 行序元数据（C-02 首卡抢焦）：模板可写 `"autofocus": "{{__first}}"`
              // 让第一项拿焦点。注入是**副本**，不改调用方数据。
              final data = <String, dynamic>{
                for (final e in row.entries) '${e.key}': e.value,
                '__index': index,
                '__first': index == 0,
              };
              final bound = applyDataToWidget(widget.template, data);
              return Builder(
                builder: (context) =>
                    Stac.fromJson(bound, context) ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
        if (m.loadingMore == true)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          ),
        if (m.footer != null)
          SliverToBoxAdapter(
            child: m.footer!.parse(context) ?? const SizedBox.shrink(),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
