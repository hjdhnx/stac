// listView / lazyGrid 滚动保持（DaoBox PROMPT-REPAIR P1-3）：
// 1. `key` → PageStorage 保留偏移（滚动容器销毁重建后位置不丢）；
// 2. `scrollTo` 指令 → 值变化就滚到目标（含 token 重复触发）；
// 3. `onScroll` → 节流回调，注入宿主的 offset/max/viewport。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stac/stac.dart';

/// 记录 onScroll 回调的探针动作（stac 单测不依赖 DaoBox 的 js.call）。
final List<Map<String, dynamic>> scrollHits = <Map<String, dynamic>>[];

class _ProbeAction extends StacActionParser<Map<String, dynamic>> {
  const _ProbeAction();

  @override
  String get actionType => 'test.probe';

  @override
  Map<String, dynamic> getModel(Map<String, dynamic> json) => json;

  @override
  FutureOr<dynamic> onCall(BuildContext context, Map<String, dynamic> model) {
    final raw = model['args'];
    scrollHits.add(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
    return null;
  }
}

Map<String, dynamic> listJson({
  String? key,
  double? initialOffset,
  Object? scrollTo,
  String? scrollToToken,
  Map<String, dynamic>? onScroll,
  int throttleMs = 100,
  int count = 40,
}) {
  final json = <String, dynamic>{
    'type': 'listView',
    'children': <Map<String, dynamic>>[
      for (var i = 0; i < count; i++)
        <String, dynamic>{'type': 'sizedBox', 'height': 100},
    ],
  };
  if (key != null) json['key'] = key;
  if (initialOffset != null) json['initialScrollOffset'] = initialOffset;
  if (scrollTo != null) json['scrollTo'] = scrollTo;
  if (scrollToToken != null) json['scrollToToken'] = scrollToToken;
  if (onScroll != null) json['onScroll'] = onScroll;
  json['scrollThrottleMs'] = throttleMs;
  return json;
}

Map<String, dynamic> gridJson({
  String? key,
  double? initialOffset,
  Object? scrollTo,
  Map<String, dynamic>? onScroll,
}) {
  final json = <String, dynamic>{
    'type': 'lazyGrid',
    'crossAxisCount': 2,
    'mainAxisExtent': 100,
    'scrollThrottleMs': 100,
    'items': <Map<String, dynamic>>[
      for (var i = 0; i < 40; i++) <String, dynamic>{'t': 'row $i'},
    ],
    'itemTemplate': <String, dynamic>{
      'type': 'sizedBox',
      'height': 100,
      'child': <String, dynamic>{'type': 'text', 'data': '{{t}}'},
    },
  };
  if (key != null) json['key'] = key;
  if (initialOffset != null) json['initialScrollOffset'] = initialOffset;
  if (scrollTo != null) json['scrollTo'] = scrollTo;
  if (onScroll != null) json['onScroll'] = onScroll;
  return json;
}

/// 稳定的宿主：PageStorage 桶挂在路由上，只有列表子树被换掉——
/// 这才是「页面内局部重建」的真实形态（整体换 MaterialApp 会连桶一起丢）。
Widget app(ValueNotifier<Map<String, dynamic>> page) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: page,
            builder: (context, json, _) =>
                Stac.fromJson(json, context) ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

double pixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  setUpAll(() async {
    await Stac.initialize(actionParsers: <StacActionParser>[
      const _ProbeAction(),
    ]);
  });

  setUp(scrollHits.clear);

  group('key → PageStorage 偏移保持', () {
    testWidgets('同 key 下滚动容器销毁重建后位置不丢', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(listJson(key: 'feed.home'));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      final before = pixels(tester);
      expect(before, greaterThan(200));

      // 模拟页面局部重建：列表子树短暂换成别的形态，再换回来。
      page.value = <String, dynamic>{'type': 'sizedBox', 'height': 10};
      await tester.pumpAndSettle();
      page.value = listJson(key: 'feed.home');
      await tester.pumpAndSettle();

      expect(pixels(tester), closeTo(before, 1.0));
    });

    testWidgets('无 key 时重建回顶（对照，证明是 key 在起作用）', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(listJson());
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(pixels(tester), greaterThan(200));

      page.value = <String, dynamic>{'type': 'sizedBox', 'height': 10};
      await tester.pumpAndSettle();
      page.value = listJson();
      await tester.pumpAndSettle();

      expect(pixels(tester), 0.0);
    });

    testWidgets('lazyGrid 同样按 key 保留偏移', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(gridJson(key: 'feed.grid'));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      final before = pixels(tester);
      expect(before, greaterThan(200));

      page.value = <String, dynamic>{'type': 'sizedBox', 'height': 10};
      await tester.pumpAndSettle();
      page.value = gridJson(key: 'feed.grid');
      await tester.pumpAndSettle();

      expect(pixels(tester), closeTo(before, 1.0));
    });
  });

  group('scrollTo 指令', () {
    testWidgets('值变化滚到目标（并钳制在上限内）', (tester) async {
      final page =
          ValueNotifier<Map<String, dynamic>>(listJson(key: 'feed.a'));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      expect(pixels(tester), 0.0);

      page.value = listJson(key: 'feed.a', scrollTo: 600);
      await tester.pumpAndSettle();
      expect(pixels(tester), closeTo(600, 1.0));

      page.value = listJson(key: 'feed.a', scrollTo: 99999);
      await tester.pumpAndSettle();
      final s = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(pixels(tester), closeTo(s.position.maxScrollExtent, 1.0));
    });

    testWidgets('同 offset + 新 token 可重复触发（回顶按钮连点）', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
          listJson(key: 'feed.b', scrollTo: 500, scrollToToken: 't1'));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      expect(pixels(tester), closeTo(500, 1.0));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pumpAndSettle();
      final moved = pixels(tester);
      expect(moved, lessThan(400));

      page.value =
          listJson(key: 'feed.b', scrollTo: 500, scrollToToken: 't2');
      await tester.pumpAndSettle();
      expect(pixels(tester), closeTo(500, 1.0));
    });
  });

  group('onScroll 节流回调', () {
    testWidgets('滚动触发动作并注入 offset/max/viewport', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(listJson(
        key: 'feed.c',
        onScroll: <String, dynamic>{
          'actionType': 'test.probe',
          'args': <String, dynamic>{'source': 'feed'},
        },
      ));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      expect(scrollHits, isEmpty, reason: '没滚动不应回调');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(scrollHits, isNotEmpty);
      final last = scrollHits.last;
      expect(last['source'], 'feed', reason: '原 args 必须保留');
      expect(last['offset'], isA<num>());
      expect(last['max'], isA<num>());
      expect(last['viewport'], isA<num>());
      expect((last['offset'] as num).toDouble(), closeTo(pixels(tester), 1.0),
          reason: '节流后仍要上报最终位置');
      expect(scrollHits.length, lessThan(10), reason: '100ms 节流不应逐帧回调');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lazyGrid 的 onScroll 同样生效', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(gridJson(
        key: 'grid.c',
        onScroll: <String, dynamic>{'actionType': 'test.probe'},
      ));
      addTearDown(page.dispose);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(scrollHits, isNotEmpty);
      expect(scrollHits.last['offset'], isA<num>());
      await tester.pumpWidget(const SizedBox());
    });
  });
}
