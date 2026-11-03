import 'package:material_ui/material_ui.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/foundation/colors/stac_brightness_parser.dart';
import 'package:stac/src/parsers/foundation/decoration/stac_input_decoration_parser.dart';
import 'package:stac/src/parsers/foundation/forms/stac_autovalidate_mode_parser.dart';
import 'package:stac/src/parsers/foundation/forms/stac_input_formatter_type_parser.dart';
import 'package:stac/src/parsers/foundation/forms/stac_max_length_enforcement_parser.dart';
import 'package:stac/src/parsers/foundation/geometry/stac_edge_insets_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_smart_dashes_type_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_smart_quotes_type_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_align_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_capitalization_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_direction_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_input_action_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_input_type_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_style_parser.dart';
import 'package:stac/src/parsers/widgets/stac_form/stac_form_scope.dart';
import 'package:stac/src/utils/action_debouncer.dart';
import 'package:stac/src/utils/clear_button_decoration.dart';
import 'package:stac/src/utils/color_utils.dart';
import 'package:stac/src/utils/input_validations.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';
import 'package:stac_logger/stac_logger.dart';

class StacTextFormFieldParser extends StacParser<StacTextFormField> {
  const StacTextFormFieldParser();

  @override
  StacTextFormField getModel(Map<String, dynamic> json) =>
      StacTextFormField.fromJson(json);

  @override
  String get type => WidgetType.textFormField.name;

  @override
  Widget parse(BuildContext context, StacTextFormField model) {
    return _TextFormFieldWidget(model, StacFormScope.of(context));
  }
}

class _TextFormFieldWidget extends StatefulWidget {
  const _TextFormFieldWidget(this.model, this.formScope);

  final StacTextFormField model;
  final StacFormScope? formScope;

  @override
  State<_TextFormFieldWidget> createState() => _TextFormFieldWidgetState();
}

class _TextFormFieldWidgetState extends State<_TextFormFieldWidget> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final ActionDebouncer _debouncer = ActionDebouncer();
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();

    _obscureText = widget.model.obscureText ?? false;

    String resolvedText = widget.model.initialValue ?? '';
    final id = widget.model.id;
    final scope = widget.formScope;
    if (id != null && scope != null) {
      final existing = scope.formData[id];
      if (existing != null && existing.toString().trim().isNotEmpty) {
        resolvedText = existing.toString();
      }
      scope.formData[id] = resolvedText;
    }

    _controller = TextEditingController(text: resolvedText);
    _lastClearValue = widget.model.clearValue;
    // D1-02：获焦全选（地址栏）。只在获焦那一次生效，之后用户自己点的
    // 光标位置不覆盖。
    if (widget.model.selectAllOnFocus == true) {
      _focusNode.addListener(_selectAllOnFocus);
    }
  }

  /// 获焦即全选。
  void _selectAllOnFocus() {
    if (!_focusNode.hasFocus || !mounted) return;
    final text = _controller.text;
    if (text.isEmpty) return;
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  /// clearValue 重置令牌（DaoBox：聊天输入「发送后清空」/ 编辑器「切 tab
  /// 换文件」）：token 与上次构建不同 → 控制器重置为当前 initialValue 一次
  /// 并同步 formScope（initialValue='' 即清空语义）。
  String? _lastClearValue;

  @override
  void didUpdateWidget(covariant _TextFormFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cur = widget.model.clearValue;
    if (cur != null && cur != _lastClearValue) {
      _lastClearValue = cur;
      _debouncer.cancel();
      _controller.text = widget.model.initialValue ?? '';
      final id = widget.model.id;
      if (id != null) widget.formScope?.formData[id] = _controller.text;
    }
  }

  void _dispatch(StacAction? action) {
    if (action == null || !mounted) return;
    action.parse(context);
  }

  void _storeValue(String value) {
    final id = widget.model.id;
    if (id != null) widget.formScope?.formData[id] = value;
  }

  void _onChanged(String value) {
    _storeValue(value);
    final action = widget.model.onChanged;
    if (action == null) return;
    final debounce = widget.model.onChangedDebounce;
    if (debounce != null && debounce > 0) {
      _debouncer.schedule(debounce, () => _dispatch(widget.model.onChanged));
    } else {
      _dispatch(action);
    }
  }

  void _onSubmitted(String value) {
    // 提交前先落一次值：用户直接回车时 onChanged 可能被节流吞掉尾巴。
    _storeValue(value);
    _debouncer.cancel();
    _dispatch(widget.model.onSubmitted);
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    _storeValue('');
    _dispatch(widget.model.onChanged);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onChanged,
      onFieldSubmitted: _onSubmitted,
      keyboardType: widget.model.keyboardType?.parse,
      textInputAction: widget.model.textInputAction?.parse,
      textCapitalization:
          widget.model.textCapitalization?.parse ?? TextCapitalization.none,
      textAlign: widget.model.textAlign?.parse ?? TextAlign.start,
      textDirection: widget.model.textDirection?.parse,
      readOnly: widget.model.readOnly ?? false,
      showCursor: widget.model.showCursor,
      autofocus: widget.model.autofocus ?? false,
      autovalidateMode: widget.model.autovalidateMode?.parse,
      obscuringCharacter: widget.model.obscuringCharacter ?? '•',
      maxLines: widget.model.maxLines ?? 1,
      minLines: widget.model.minLines,
      maxLength: widget.model.maxLength,
      obscureText: _obscureText,
      autocorrect: widget.model.autocorrect ?? true,
      smartDashesType: widget.model.smartDashesType?.parse,
      smartQuotesType: widget.model.smartQuotesType?.parse,
      maxLengthEnforcement: widget.model.maxLengthEnforcement?.parse,
      expands: widget.model.expands ?? false,
      keyboardAppearance: widget.model.keyboardAppearance?.parse,
      scrollPadding:
          widget.model.scrollPadding?.parse ?? const EdgeInsets.all(20),
      restorationId: widget.model.restorationId,
      enableIMEPersonalizedLearning:
          widget.model.enableIMEPersonalizedLearning ?? true,
      enableSuggestions: widget.model.enableSuggestions ?? true,
      enabled: widget.model.enabled,
      cursorWidth: widget.model.cursorWidth ?? 2.0,
      cursorHeight: widget.model.cursorHeight,
      cursorColor: widget.model.cursorColor?.toColor(context),
      style: widget.model.style?.parse(context),
      decoration: _decorationWithClearButton(context),
      inputFormatters: widget.model.inputFormatters
          ?.map(
            (inputFormatter) => inputFormatter.type.parse.format(
              inputFormatter.rule ?? "",
              mask: inputFormatter.mask,
            ),
          )
          .toList(),
      validator: (value) {
        return _validate(value, widget.model);
      },
    );
  }

  InputDecoration? _decorationWithClearButton(BuildContext context) {
    final decoration = widget.model.decoration?.parse(context);
    final needsButton = widget.model.clearButton == true &&
        widget.model.readOnly != true &&
        widget.model.enabled != false;
    if (!needsButton) return decoration;
    return applyClearButton(
      decoration: decoration,
      controller: _controller,
      onClear: _clear,
    );
  }

  String? _validate(String? value, StacTextFormField model) {
    if (value == null || !(model.validatorRules?.isNotEmpty ?? false)) {
      return null;
    }

    for (final validator in model.validatorRules!) {
      try {
        bool isValid;
        if (validator.rule == 'compare') {
          final targetId = validator.options?['fieldId'] as String?;
          final target = targetId == null
              ? null
              : widget.formScope?.formData[targetId]?.toString();
          isValid = value == target;
        } else {
          isValid = InputValidators.validate(
            validator.rule,
            value,
            options: validator.options,
          );
        }

        if (!isValid) return validator.message ?? 'Invalid input';
      } catch (e) {
        Log.e(e);
        return validator.message ?? 'Invalid input';
      }
    }

    return null;
  }

  @override
  void dispose() {
    if (widget.model.selectAllOnFocus == true) {
      _focusNode.removeListener(_selectAllOnFocus);
    }
    _debouncer.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
