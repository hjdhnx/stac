import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

/// 给输入框装饰加上「有值即出」的清除按钮。
///
/// 与 DsPlayer `clearable_text_field` 同口径：**组合** suffix 槽位而不是抢占
/// ——已有 suffixIcon（搜索图标/单位/清除外的操作）时并排放在它右边；没有
/// 时单独占位。空文本时隐藏（不 reshape，保持槽位宽度稳定）。
InputDecoration applyClearButton({
  required InputDecoration? decoration,
  required ValueListenable<TextEditingValue> controller,
  required VoidCallback onClear,
}) {
  final base = decoration ?? const InputDecoration();
  final clear = ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      if (value.text.isEmpty) return const SizedBox.shrink();
      return IconButton(
        icon: const Icon(Icons.clear, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: onClear,
      );
    },
  );
  final existing = base.suffixIcon;
  if (existing == null) return base.copyWith(suffixIcon: clear);
  return base.copyWith(
    suffixIcon: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[existing, clear],
    ),
  );
}
