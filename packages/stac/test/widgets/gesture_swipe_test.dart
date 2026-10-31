// GestureDetector.onSwipe（DaoBox PROMPT-REPAIR P1-5）：
// 1. 位移/速度双阈值：达标才派发，派发时带上 {dx, velocity}；
// 2. 快捷轻扫（位移不够但速度够）也算 swipe；
// 3. 未配置 onSwipe 时行为不变（不注册水平识别器）；
// 4. clearButton 与已有 suffixIcon 组合（不抢占槽位）。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stac/stac.dart';

/// 记录每次派发的动作 JSON（含 stac 合入的 dx / velocity）。
final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
int probeHits = 0;

class _ProbeAction extends StacActionParser<Map<String, dynamic>> {
  const _ProbeAction();

  @override
  String get actionType => 'test.probe';

  @override
  Map<String, dynamic> getModel(Map<String, dynamic> json) => json;

  @override
  FutureOr<dynamic> onCall(BuildContext context, Map<String, dynamic> model) {
    probeHits++;
    return null;
  }
}

class _RecordAction extends StacActionParser<Map<String, dynamic>> {
  const _RecordAction();

  @override
  String get actionType => 'test.record';

  @override
  Map<String, dynamic> getModel(Map<String, dynamic> json) => json;

  @override
  FutureOr<dynamic> onCall(BuildContext context, Map<String, dynamic> model) {
    calls.add(model);
    return null;
  }
}

const Map<String, dynamic> probe = <String, dynamic>{
  'actionType': 'test.probe',
};

Map<String, dynamic> swipeJson({
  Map<String, dynamic>? onSwipe,
  double? minDistance,
  double? minVelocity,
}) {
  final json = <String, dynamic>{
    'type': 'gestureDetector',
    'behavior': 'opaque',
    'child': <String, dynamic>{
      'type': 'container',
      'width': 300,
      'height': 300,
      'color': '#FF0000',
    },
  };
  if (onSwipe != null) json['onSwipe'] = onSwipe;
  if (minDistance != null) json['swipeMinDistance'] = minDistance;
  if (minVelocity != null) json['swipeMinVelocity'] = minVelocity;
  return json;
}

Widget host(Map<String, dynamic> json) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) =>
                Stac.fromJson(json, context) ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    await Stac.initialize(actionParsers: <StacActionParser>[
      const _ProbeAction(),
      const _RecordAction(),
    ]);
  });

  setUp(() {
    probeHits = 0;
    calls.clear();
  });

  group('onSwipe', () {
    testWidgets('位移达标：派发一次并带 dx/velocity（左滑为负）', (tester) async {
      await tester.pumpWidget(host(swipeJson(onSwipe: probe)));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump();
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(probeHits, 1, reason: '累积位移 80 > 默认 60 应派发');
    });

    testWidgets('位移与速度都不达标：不派发', (tester) async {
      await tester.pumpWidget(host(swipeJson(onSwipe: probe)));
      await tester.pumpAndSettle();

      // 20px 慢拖（远低于 60px 且速度很低）
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump();
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(probeHits, 0);
    });

    testWidgets('快速轻扫（位移不足、速度够）也派发', (tester) async {
      await tester.pumpWidget(host(swipeJson(onSwipe: <String, dynamic>{
        'actionType': 'test.record',
        'args': <String, dynamic>{},
      })));
      await tester.pumpAndSettle();

      // 45px / 20ms ≈ 2250px/s：越过 18px 触摸槽（否则识别器根本不接管），
      // 累计位移仍低于默认 60px——能不能派发全靠速度。
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await gesture.moveBy(const Offset(-25, 0),
          timeStamp: const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.moveBy(const Offset(-20, 0),
          timeStamp: const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 10));
      await gesture.up(timeStamp: const Duration(milliseconds: 30));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1), reason: 'calls=$calls');
    });

    testWidgets('阈值可覆盖：调高后同样的手势不再派发', (tester) async {
      await tester.pumpWidget(
        host(swipeJson(onSwipe: probe, minDistance: 200, minVelocity: 5000)),
      );
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump();
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(probeHits, 0);
    });

    testWidgets('动作原有的 args 被保留，dx/velocity 合入', (tester) async {
      await tester.pumpWidget(host(swipeJson(onSwipe: <String, dynamic>{
        'actionType': 'test.record',
        'args': <String, dynamic>{'dir': 'hint', 'keep': 7},
      })));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      final args = calls.single['args'] as Map<String, dynamic>;
      expect(args['dir'], 'hint');
      expect(args['keep'], 7);
      expect(args['dx'], closeTo(80, 1));
      expect(args['velocity'], isA<num>());
      expect(args['dx'] as num, greaterThan(0));
    });

    testWidgets('未配置 onSwipe：水平拖动不派发任何动作', (tester) async {
      await tester.pumpWidget(host(swipeJson()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Container), const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(probeHits, 0);
      expect(calls, isEmpty);
    });
  });

  group('clearButton 组合 suffix', () {
    testWidgets('已有 suffixIcon 时并排而非覆盖', (tester) async {
      await tester.pumpWidget(host(<String, dynamic>{
        'type': 'textField',
        'initialValue': 'abc',
        'clearButton': true,
        'decoration': <String, dynamic>{
          'suffixIcon': <String, dynamic>{
            'type': 'icon',
            'icon': 'search',
          },
        },
      }));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });
}
