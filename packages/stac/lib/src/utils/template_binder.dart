import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:stac/stac.dart';

/// Replaces `{{key}}` placeholders inside a widget JSON tree with values from
/// [data]. Nested keys use dots (`{{vod.title}}`).
///
/// Values are substituted as strings; a value that is exactly one placeholder
/// keeps its native JSON type (number, bool, map, list) so template fields
/// such as `flex: "{{flex}}"` still bind correctly.
///
/// Shared by `dynamicView` and `lazyGrid` so both bind identically.
Map<String, dynamic> applyDataToWidget(
  Map<String, dynamic> template,
  Map<dynamic, dynamic> data,
) {
  final cloned = jsonDecode(jsonEncode(template)) as Map<String, dynamic>;
  _walk(cloned, data);
  return cloned;
}

const _placeholder = r'^\{\{\s*([A-Za-z0-9_.\-\[\]]+)\s*\}\}$';
final _placeholderRe = RegExp(_placeholder);
final _inlineRe = RegExp(r'\{\{\s*([A-Za-z0-9_.\-]+)\s*\}\}');

void _walk(Object? node, Map<dynamic, dynamic> data) {
  if (node is Map) {
    for (final key in node.keys.toList()) {
      final value = node[key];
      if (value is String) {
        node[key] = _resolveString(value, data);
      } else {
        _walk(value, data);
      }
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      final value = node[i];
      if (value is String) {
        node[i] = _resolveString(value, data);
      } else {
        _walk(value, data);
      }
    }
  }
}

Object? _resolveString(String raw, Map<dynamic, dynamic> data) {
  final whole = _placeholderRe.firstMatch(raw);
  if (whole != null) {
    final value = _lookup(whole.group(1)!, data);
    return value ?? '';
  }
  if (!raw.contains('{{')) return raw;
  return raw.replaceAllMapped(_inlineRe, (m) {
    final value = _lookup(m.group(1)!, data);
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return '$value';
  });
}

Object? _lookup(String path, Map<dynamic, dynamic> data) {
  Object? current = data;
  for (final segment in path.split('.')) {
    if (current is Map) {
      current = current[segment];
    } else {
      return null;
    }
    if (current == null) return null;
  }
  return current;
}

/// Applies a `{{}}` template to every row; rows that are not maps are skipped.
List<Map<String, dynamic>> applyRows(
  Map<String, dynamic> template,
  List<dynamic> rows,
) {
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    if (row is Map) {
      out.add(applyDataToWidget(template, row));
    }
  }
  return out;
}

/// Small helper for parsers that need to turn a bound JSON tree into widgets.
Widget? parseBound(BuildContext context, Map<String, dynamic> json) =>
    Stac.fromJson(json, context);
