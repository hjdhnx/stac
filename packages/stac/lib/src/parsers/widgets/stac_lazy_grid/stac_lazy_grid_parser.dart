import 'package:material_ui/material_ui.dart';
import 'package:stac/src/framework/framework.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/core/stac_widget_parser.dart';
import 'package:stac/src/parsers/foundation/geometry/stac_edge_insets_parser.dart';
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
    if (template == null || rows.isEmpty) {
      // 空态也要保留 header/footer：筛选条在 header 里，否则用户无法切回有数据的分类。
      return CustomScrollView(
        slivers: [
          if (model.header != null)
            SliverToBoxAdapter(
              child: model.header!.parse(context) ?? const SizedBox.shrink(),
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
    );
  }
}

class _LazyGridScroll extends StatefulWidget {
  const _LazyGridScroll({
    required this.model,
    required this.template,
    required this.rows,
  });

  final StacLazyGrid model;
  final Map<String, dynamic> template;
  final List<dynamic> rows;

  @override
  State<_LazyGridScroll> createState() => _LazyGridScrollState();
}

class _LazyGridScrollState extends State<_LazyGridScroll> {
  final _controller = ScrollController();
  bool _armed = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _LazyGridScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新数据到达（条目数变化）后才允许再次触发，避免滚动抖动里连发。
    if (oldWidget.rows.length != widget.rows.length) _armed = true;
  }

  void _onScroll() {
    final m = widget.model;
    if (!_armed || m.hasMore != true || m.loadingMore == true) return;
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final threshold = m.endReachedThreshold ?? 320;
    if (pos.pixels >= pos.maxScrollExtent - threshold) {
      _armed = false;
      m.onEndReached?.parse(context);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final padding = m.padding?.parse ?? EdgeInsets.zero;
    final rows = widget.rows;

    return CustomScrollView(
      controller: _controller,
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
              final bound = applyDataToWidget(widget.template, row);
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
