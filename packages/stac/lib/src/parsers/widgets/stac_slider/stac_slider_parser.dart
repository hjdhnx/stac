import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_mouse_cursor_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_slider_interaction_parser.dart';
import 'package:stac/src/parsers/widgets/stac_form/stac_form_scope.dart';
import 'package:stac/src/utils/action_debouncer.dart';
import 'package:stac/src/utils/color_utils.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

class StacSliderParser extends StacParser<StacSlider> {
  const StacSliderParser();

  @override
  String get type => WidgetType.slider.name;

  @override
  StacSlider getModel(Map<String, dynamic> json) => StacSlider.fromJson(json);

  @override
  Widget parse(BuildContext context, StacSlider model) {
    return _StacSlider(model, StacFormScope.of(context));
  }
}

class _StacSlider extends StatefulWidget {
  const _StacSlider(this.model, this.formScope);

  final StacSlider model;
  final StacFormScope? formScope;

  @override
  State<_StacSlider> createState() => __StacSliderState();
}

class __StacSliderState extends State<_StacSlider> {
  /// 拖动期间以本地值为准：手指还在拖时若用回包值驱动，会「拖到一半被旧值
  /// 拽回去」（每帧一次整页重算 + 回包覆盖的竞态）。
  late double selectedValue;

  /// 旧实现在 build 里每帧 new FocusNode 且从不 dispose —— 焦点每帧丢一次。
  final FocusNode _focusNode = FocusNode();

  final ActionDebouncer _debouncer = ActionDebouncer();
  bool _dragging = false;

  /// 最近一次已派发的值，用于拖动结束时跳过重复派发（debounce 尾触发刚发过
  /// 同一个值时不重复触发整页重算）。
  double? _lastDispatched;

  @override
  void initState() {
    selectedValue = widget.model.value;
    _syncFormData(selectedValue);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _StacSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final model = widget.model;
    if (_dragging) {
      // 拖动中忽略回包：此刻 model.value 还是上一帧的旧值。
      if (oldWidget.model.id != model.id) _syncFormData(selectedValue);
      return;
    }
    if (oldWidget.model.value != model.value ||
        oldWidget.model.id != model.id) {
      selectedValue = model.value;
      _syncFormData(selectedValue);
    }
  }

  void _syncFormData(double value) {
    final id = widget.model.id;
    if (id != null) widget.formScope?.formData[id] = value;
  }

  void _dispatch(StacAction? action) {
    if (action == null || !mounted) return;
    action.parse(context);
  }

  void _onChanged(double value) {
    selectedValue = value;
    _syncFormData(value);

    final debounce = widget.model.debounce;
    // debounce == null：拖动期间不发动作，等 onChangeEnd（或无 onChangeEnd
    // 时在结束时补发 onChanged）一次提交——松手前不会有整页重算插进来。
    if (debounce != null) {
      _debouncer.schedule(debounce, () {
        _lastDispatched = selectedValue;
        _dispatch(widget.model.onChanged);
      });
    }

    setState(() {});
  }

  void _onChangeStart(double value) {
    _dragging = true;
    _dispatch(widget.model.onChangeStart);
  }

  void _onChangeEnd(double value) {
    _dragging = false;
    selectedValue = value;
    _syncFormData(value);
    _debouncer.cancel();

    final model = widget.model;
    if (model.onChangeEnd != null) {
      _dispatch(model.onChangeEnd);
    } else if (model.onChanged != null && _lastDispatched != value) {
      _dispatch(model.onChanged);
    }
    _lastDispatched = value;

    setState(() {});
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StacSlider model = widget.model;

    switch (model.sliderType ?? StacSliderType.adaptive) {
      case StacSliderType.material:
        return _buildMaterialSlider(model, selectedValue);
      case StacSliderType.adaptive:
        return _buildAdaptiveSlider(model, selectedValue);
      case StacSliderType.cupertino:
        return _buildCupertinoSlider(model, selectedValue);
    }
  }

  Widget _buildMaterialSlider(StacSlider model, double value) {
    return Slider(
      value: value,
      secondaryTrackValue: model.secondaryTrackValue,
      onChanged: (value) => _onChanged(value),
      onChangeStart: (value) => _onChangeStart(value),
      onChangeEnd: (value) => _onChangeEnd(value),
      min: model.min ?? 0.0,
      max: model.max ?? 1.0,
      divisions: model.divisions,
      label: model.label,
      activeColor: model.activeColor?.toColor(context),
      inactiveColor: model.inactiveColor?.toColor(context),
      secondaryActiveColor: model.secondaryActiveColor?.toColor(context),
      thumbColor: model.thumbColor?.toColor(context),
      overlayColor: WidgetStateProperty.all(
        model.overlayColor?.toColor(context),
      ),
      mouseCursor: model.mouseCursor?.parse,
      focusNode: _focusNode,
      autofocus: model.autofocus ?? false,
      allowedInteraction: model.allowedInteraction?.parse,
    );
  }

  Widget _buildAdaptiveSlider(StacSlider model, double value) {
    return Slider.adaptive(
      value: value,
      secondaryTrackValue: model.secondaryTrackValue,
      onChanged: (value) => _onChanged(value),
      onChangeStart: (value) => _onChangeStart(value),
      onChangeEnd: (value) => _onChangeEnd(value),
      min: model.min ?? 0.0,
      max: model.max ?? 1.0,
      divisions: model.divisions,
      label: model.label,
      activeColor: model.activeColor?.toColor(context),
      inactiveColor: model.inactiveColor?.toColor(context),
      secondaryActiveColor: model.secondaryActiveColor?.toColor(context),
      thumbColor: model.thumbColor?.toColor(context),
      overlayColor: WidgetStateProperty.all(
        model.overlayColor?.toColor(context),
      ),
      mouseCursor: model.mouseCursor?.parse,
      focusNode: _focusNode,
      autofocus: model.autofocus ?? false,
      allowedInteraction: model.allowedInteraction?.parse,
    );
  }

  Widget _buildCupertinoSlider(StacSlider model, double value) {
    return CupertinoSlider(
      value: value,
      onChanged: (value) => _onChanged(value),
      onChangeStart: (value) => _onChangeStart(value),
      onChangeEnd: (value) => _onChangeEnd(value),
      min: model.min ?? 0.0,
      max: model.max ?? 1.0,
      divisions: model.divisions,
      activeColor: model.activeColor?.toColor(context),
      thumbColor: model.thumbColor?.toColor(context) ?? CupertinoColors.white,
    );
  }
}
