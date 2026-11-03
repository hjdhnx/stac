// slider 本地值与动作节流 + textField/textFormField 能力（DaoBox PROMPT-REPAIR P1-4）：
// 1. slider 拖动期间不发动作（默认松手才发）、拖动中回包不覆盖本地值、
//    FocusNode 跨帧稳定、debounce 支持；
// 2. textFormField：onChanged（节流）/ onSubmitted / clearButton / controller 稳定；
// 3. textField：controller/focusNode 由 State 持有，重建不丢文本。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stac/stac.dart';

/// 记录动作调用次数的探针（stac 单测不依赖 DaoBox 的 js.call）。
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

const Map<String, dynamic> probe = <String, dynamic>{
  'actionType': 'test.probe',
};

Map<String, dynamic> sliderJson({
  double value = 0,
  double min = 0,
  double max = 100,
  Object? debounce,
  String? id,
  bool withProbe = true,
}) {
  final json = <String, dynamic>{
    'type': 'slider',
    'value': value,
    'min': min,
    'max': max,
    'sliderType': 'material',
    'onChanged': withProbe ? probe : null,
  };
  if (debounce != null) json['debounce'] = debounce;
  if (id != null) json['id'] = id;
  return json;
}

Map<String, dynamic> textFormFieldJson({
  String type = 'textFormField',
  String? initialValue,
  Map<String, dynamic>? onChanged,
  Map<String, dynamic>? onSubmitted,
  Object? debounce,
  bool clearButton = false,
}) {
  final json = <String, dynamic>{'type': type};
  if (initialValue != null) json['initialValue'] = initialValue;
  if (onChanged != null) json['onChanged'] = onChanged;
  if (onSubmitted != null) json['onSubmitted'] = onSubmitted;
  if (debounce != null) json['onChangedDebounce'] = debounce;
  if (clearButton) json['clearButton'] = true;
  return json;
}

/// 表单数据宿主：控件按 id 写入，动作 formFields 从这里取值（DaoBox 同款路径）。
final Map<String, dynamic> formData = <String, dynamic>{};

Widget host(ValueNotifier<Map<String, dynamic>> page) => MaterialApp(
      home: Scaffold(
        body: StacFormScope(
          formData: formData,
          formKey: GlobalKey<FormState>(),
          child: SizedBox(
            width: 400,
            height: 400,
            child: ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: page,
              builder: (context, json, _) =>
                  Stac.fromJson(json, context) ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

double sliderValue(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider)).value;

void main() {
  setUpAll(() async {
    await Stac.initialize(actionParsers: <StacActionParser>[
      const _ProbeAction(),
    ]);
  });

  setUp(() {
    probeHits = 0;
    formData.clear();
  });

  group('slider', () {
    testWidgets('默认：拖动期间不发动作，松手只发一次', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        sliderJson(value: 0, id: 'sheet.volume'),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      // 拖动中：本地值跟手，但不派发动作（每帧派发 = 整页重算）。
      expect(sliderValue(tester), greaterThan(0));
      expect(probeHits, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(probeHits, 1);
      // 松手时表单值已落定：动作 formFields:[id] 在派发时刻能取到最终值。
      expect(formData['sheet.volume'], sliderValue(tester));
    });

    testWidgets('拖动中回包（旧值）不覆盖本地值', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        sliderJson(value: 0, id: 'sheet.volume'),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      final dragged = sliderValue(tester);
      expect(dragged, greaterThan(0));

      // 模拟拖动期间父级重建带回旧值（回包/无关刷新）。
      page.value = sliderJson(value: 0, id: 'sheet.volume');
      await tester.pump();
      expect(sliderValue(tester), closeTo(dragged, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('FocusNode 跨重建稳定', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(sliderJson(value: 10));
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();
      final first = tester.widget<Slider>(find.byType(Slider)).focusNode;

      page.value = sliderJson(value: 40);
      await tester.pumpAndSettle();
      final second = tester.widget<Slider>(find.byType(Slider)).focusNode;

      expect(identical(first, second), isTrue);
      expect(sliderValue(tester), 40);
    });

    testWidgets('debounce=0 保持每帧派发（旧行为可显式开启）', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        sliderJson(value: 0, debounce: 0),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(probeHits, greaterThanOrEqualTo(2));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('debounce=100：安静 100ms 才派发，松手不重复派发同值', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        sliderJson(value: 0, debounce: 100),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 40));
      expect(probeHits, 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(probeHits, 1);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(probeHits, 1);
    });
  });

  group('textFormField', () {
    testWidgets('重建不丢文本（controller 由 State 持有）', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        textFormFieldJson(initialValue: ''),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();

      page.value = textFormFieldJson(initialValue: '');
      await tester.pumpAndSettle();
      expect(find.text('abc'), findsOneWidget);
    });

    testWidgets('onChanged 按 onChangedDebounce 节流（尾触发）', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        textFormFieldJson(onChanged: probe, debounce: 80),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      final finder = find.byType(TextFormField);
      await tester.enterText(finder, 'a');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.enterText(finder, 'ab');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.enterText(finder, 'abc');
      await tester.pump(const Duration(milliseconds: 20));
      expect(probeHits, 0);

      await tester.pump(const Duration(milliseconds: 120));
      expect(probeHits, 1);
    });

    testWidgets('onSubmitted 立即派发', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        textFormFieldJson(
          onChanged: probe,
          onSubmitted: probe,
          debounce: 500,
        ),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // onChanged 的尾巴被提交取消，只剩 onSubmitted 这一次。
      expect(probeHits, 1);

      await tester.pump(const Duration(milliseconds: 600));
      expect(probeHits, 1);
    });

    testWidgets('clearButton 清空文本并派发 onChanged', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        textFormFieldJson(onChanged: probe, clearButton: true),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
      final beforeClear = probeHits;

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text, '');
      expect(probeHits, beforeClear + 1);
    });
  });

  group('textField', () {
    testWidgets('重建不丢文本，clearButton 可用', (tester) async {
      final page = ValueNotifier<Map<String, dynamic>>(
        textFormFieldJson(
          type: 'textField',
          initialValue: 'seed',
          clearButton: true,
        ),
      );
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      expect(find.text('seed'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'typed');
      await tester.pump();

      page.value = textFormFieldJson(
        type: 'textField',
        initialValue: 'seed',
        clearButton: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('typed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('typed'), findsNothing);
    });

    testWidgets('selectAllOnFocus：获焦全选全文（地址栏）', (tester) async {
      final json = textFormFieldJson(
        type: 'textField',
        initialValue: 'https://a.example/path',
      );
      json['selectAllOnFocus'] = true;
      final page = ValueNotifier<Map<String, dynamic>>(json);
      addTearDown(page.dispose);
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      // 未获焦时不动选择区
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.selection.isValid,
          isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final ctrl = tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(ctrl.selection.baseOffset, 0);
      expect(ctrl.selection.extentOffset, 'https://a.example/path'.length);

      // 用户自己点回去改字：光标位置不被强行重置
      ctrl.selection = const TextSelection.collapsed(offset: 3);
      await tester.pumpAndSettle();
      expect(ctrl.selection.baseOffset, 3);
    });
  });
}
