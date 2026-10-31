import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/foundation/decoration/stac_input_decoration_parser.dart';
import 'package:stac/src/parsers/foundation/geometry/stac_edge_insets_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_drag_start_behavior_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_mouse_cursor_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_scroll_physics_parser.dart';
import 'package:stac/src/parsers/foundation/layout/stac_clip_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_align_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_capitalization_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_direction_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_input_action_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_input_type_parser.dart';
import 'package:stac/src/parsers/foundation/text/stac_text_style_parser.dart';
import 'package:stac/src/utils/action_debouncer.dart';
import 'package:stac/src/utils/color_utils.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

class StacTextFieldParser extends StacParser<StacTextField> {
  const StacTextFieldParser({this.controller, this.focusNode});

  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  StacTextField getModel(Map<String, dynamic> json) =>
      StacTextField.fromJson(json);

  @override
  String get type => WidgetType.textField.name;

  @override
  Widget parse(BuildContext context, StacTextField model) {
    return _TextFieldWidget(
      model,
      controller: controller,
      focusNode: focusNode,
    );
  }
}

/// 有状态的 TextField 包装：旧实现在 `parse` 里现建 controller/focusNode，
/// 每次页面重建都会换一套 → 文本与光标丢失。这里只在首帧建一次。
class _TextFieldWidget extends StatefulWidget {
  const _TextFieldWidget(this.model, {this.controller, this.focusNode});

  final StacTextField model;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  late final bool _ownsFocusNode;
  final ActionDebouncer _debouncer = ActionDebouncer();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;

    final initialValue = widget.model.initialValue;
    if (widget.controller != null) {
      _controller = widget.controller!;
      if ((initialValue ?? '').isNotEmpty) _controller.text = initialValue!;
    } else {
      _controller = TextEditingController(text: initialValue ?? '');
    }
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant _TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialValue = widget.model.initialValue;
    if (initialValue != null &&
        initialValue != oldWidget.model.initialValue &&
        !_focusNode.hasFocus &&
        _controller.text != initialValue) {
      _controller.text = initialValue;
    }
  }

  void _dispatch(StacAction? action) {
    if (action == null || !mounted) return;
    action.parse(context);
  }

  void _onChanged(String value) {
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
    _debouncer.cancel();
    _dispatch(widget.model.onSubmitted);
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    _dispatch(widget.model.onChanged);
  }

  InputDecoration? _decorationWithClearButton(BuildContext context) {
    final decoration = widget.model.decoration?.parse(context);
    final needsButton = widget.model.clearButton == true &&
        widget.model.readOnly != true &&
        widget.model.enabled != false;
    if (!needsButton) return decoration;
    return (decoration ?? const InputDecoration()).copyWith(
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (value.text.isEmpty) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(Icons.clear, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: _clear,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: model.keyboardType?.parse,
      textInputAction: model.textInputAction?.parse,
      textCapitalization:
          model.textCapitalization?.parse ?? TextCapitalization.none,
      textAlign: model.textAlign?.parse ?? TextAlign.start,
      textDirection: model.textDirection?.parse,
      readOnly: model.readOnly ?? false,
      showCursor: model.showCursor,
      autofocus: model.autofocus ?? false,
      obscuringCharacter: model.obscuringCharacter ?? '•',
      maxLines: model.maxLines,
      minLines: model.minLines,
      maxLength: model.maxLength,
      obscureText: model.obscureText ?? false,
      enableSuggestions: model.enableSuggestions ?? true,
      enabled: model.enabled,
      expands: model.expands ?? false,
      cursorWidth: model.cursorWidth ?? 2.0,
      cursorHeight: model.cursorHeight,
      cursorColor: model.cursorColor?.toColor(context),
      style: model.style?.parse(context),
      decoration: _decorationWithClearButton(context),
      scrollPadding: model.scrollPadding?.parse ?? const EdgeInsets.all(20.0),
      enableInteractiveSelection: model.enableInteractiveSelection,
      mouseCursor: model.mouseCursor?.parse,
      dragStartBehavior:
          model.dragStartBehavior?.parse ?? DragStartBehavior.start,
      scrollPhysics: model.scrollPhysics?.parse,
      restorationId: model.restorationId,
      clipBehavior: model.clipBehavior?.parse ?? Clip.hardEdge,
      autofillHints: model.autofillHints,
      onTap: model.onTap == null ? null : () => _dispatch(model.onTap),
      onChanged: _onChanged,
      onEditingComplete: model.onEditingComplete == null
          ? null
          : () => _dispatch(model.onEditingComplete),
      onSubmitted: _onSubmitted,
    );
  }

  @override
  void dispose() {
    _debouncer.dispose();
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }
}
