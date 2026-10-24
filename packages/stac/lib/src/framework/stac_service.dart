import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' hide ErrorWidgetBuilder;
import 'package:flutter/services.dart';
import 'package:stac/src/framework/stac.dart';
import 'package:stac/src/framework/stac_error.dart';
import 'package:stac/src/framework/stac_registry.dart';
import 'package:stac/src/models/stac_cache_config.dart';
import 'package:stac/src/parsers/actions/stac_form_validate/stac_form_validate_parser.dart';
import 'package:stac/src/parsers/actions/stac_get_form_value/stac_get_form_value_parser.dart';
import 'package:stac/src/parsers/actions/stac_network_request/stac_network_request_parser.dart';
import 'package:stac/src/parsers/parsers.dart';
import 'package:stac/src/parsers/widgets/stac_app_bar/stac_app_bar_parser.dart';
import 'package:stac/src/parsers/widgets/stac_inkwell/stac_inkwell_parser.dart';
import 'package:stac/src/parsers/widgets/stac_row/stac_row_parser.dart';
import 'package:stac/src/parsers/widgets/stac_text/stac_text_parser.dart';
import 'package:stac/src/parsers/widgets/stac_tool_tip/stac_tool_tip_parser.dart';
import 'package:stac/src/services/stac_network_service.dart';
import 'package:stac/src/utils/variable_resolver.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';
import 'package:stac_logger/stac_logger.dart';

/// Internal service that manages Stac parsers, actions, and rendering.
///
/// This service is the core of the Stac framework, responsible for:
/// - Registering and managing widget and action parsers
/// - Converting JSON to Flutter widgets
/// - Handling errors with proper error widgets
/// - Loading widgets from network and assets
///
/// Initialize with [initialize] before using any Stac widgets:
/// ```dart
/// await StacService.initialize(
///   parsers: [...],
///   actionParsers: [...],
///   showErrorWidgets: true,
/// );
/// ```
class StacService {
  // Error message constants
  static const String _errorWidgetTypeNotSupported =
      'Widget type not found or not supported';
  static const String _errorActionTypeNotSupported =
      'Action type not found or not supported';

  static final _parsers = <StacParser>[
    const StacContainerParser(),
    const StacTextParser(),
    const StacTextFieldParser(),
    const StacElevatedButtonParser(),
    const StacImageParser(),
    const StacIconParser(),
    const StacCenterParser(),
    const StacRowParser(),
    const StacColumnParser(),
    const StacCustomScrollViewParser(),
    const StacStackParser(),
    const StacPositionedParser(),
    const StacIconButtonParser(),
    const StacFloatingActionButtonParser(),
    const StacOutlinedButtonParser(),
    const StacPaddingParser(),
    const StacAppBarParser(),
    const StacTextButtonParser(),
    const StacScaffoldParser(),
    const StacSizedBoxParser(),
    const StacFractionallySizedBoxParser(),
    const StacTextFormFieldParser(),
    const StacTabBarViewParser(),
    const StacTabBarParser(),
    const StacListTileParser(),
    const StacCardParser(),
    const StacBottomNavigationBarParser(),
    const StacNavigationBarParser(),
    const StacListViewParser(),
    const StacDefaultTabControllerParser(),
    const StacSingleChildScrollViewParser(),
    const StacAlertDialogParser(),
    const StacTabParser(),
    const StacFormParser(),
    const StacCheckBoxParser(),
    const StacExpandedParser(),
    const StacFlexibleParser(),
    const StacSpacerParser(),
    const StacSafeAreaParser(),
    const StacSwitchParser(),
    const StacAlignParser(),
    const StacPageViewParser(),
    const StacRefreshIndicatorParser(),
    const StacNetworkWidgetParser(),
    const StacCircleAvatarParser(),
    const StacChipParser(),
    const StacGridViewParser(),
    const StacFilledButtonParser(),
    const StacBottomNavigationViewParser(),
    const StacNavigationViewParser(),
    const StacDefaultBottomNavigationControllerParser(),
    const StacDefaultNavigationControllerParser(),
    const StacWrapParser(),
    const StacAutoCompleteParser(),
    const StacBadgeParser(),
    const StacToolTipParser(),
    const StacTableParser(),
    const StacTableCellParser(),
    const StacCarouselViewParser(),
    const StacColoredBoxParser(),
    const StacDividerParser(),
    const StacDrawerParser(),
    const StacCircularProgressIndicatorParser(),
    const StacLinearProgressIndicatorParser(),
    const StacHeroParser(),
    const StacRadioParser(),
    const StacRadioGroupParser(),
    const StacSliderParser(),
    const StacSliverAppBarParser(),
    const StacSliverGridParser(),
    const StacSliverFillRemainingParser(),
    const StacSliverListParser(),
    const StacSliverVisibilityParser(),
    const StacSliverOpacityParser(),
    const StacSliverSafeAreaParser(),
    const StacSliverPaddingParser(),
    const StacSliverToBoxAdapterParser(),
    const StacOpacityParser(),
    const StacPlaceholderParser(),
    const StacAspectRatioParser(),
    const StacFittedBoxParser(),
    const StacLimitedBoxParser(),
    const StacLazyGridParser(),
    const StacIntrinsicHeightParser(),
    const StacIntrinsicWidthParser(),
    const StacDynamicViewParser(),
    const StacDropdownMenuParser(),
    const StacClipRRectParser(),
    const StacClipOvalParser(),
    const StacGestureDetectorParser(),
    const StacSetValueParser(),
    const StacInkwellParser(),
    const StacConditionalParser(),
    const StacVisibilityParser(),
    const StacBackdropFilterParser(),
    const StacVerticalDividerParser(),
    const StacSelectableTextParser(),
  ];

  static final _actionParsers = <StacActionParser>[
    const StacNoneActionParser(),
    const StacNavigateActionParser(),
    const StacNetworkRequestParser(),
    const StacModalBottomSheetActionParser(),
    const StacDialogActionParser(),
    const StacGetFormValueParser(),
    const StacFormValidateParser(),
    const StacSnackBarParser(),
    const StacSetValueActionParser(),
    const StacMultiActionParser(),
    const StacDelayActionParser(),
  ];

  static StacOptions? _options;
  static StacOptions? get options => _options;

  static bool _showErrorWidgets = true;
  static bool _logStackTraces = true;

  // Optional global parse-error widget builder supplied by the app.
  static StacErrorWidgetBuilder? _errorWidgetBuilder;

  // Default cache configuration for all Stac widgets and StacCloud calls.
  static StacCacheConfig _defaultCacheConfig = const StacCacheConfig(
    strategy: StacCacheStrategy.networkFirst,
  );
  static StacCacheConfig get defaultCacheConfig => _defaultCacheConfig;

  static Future<void> initialize({
    StacOptions? options,
    List<StacParser> parsers = const [],
    List<StacActionParser> actionParsers = const [],
    Dio? dio,
    bool override = false,
    bool showErrorWidgets = true,
    bool logStackTraces = true,
    StacErrorWidgetBuilder? errorWidgetBuilder,
    StacCacheConfig? cacheConfig,
  }) async {
    _options = options;
    if (cacheConfig != null) {
      _defaultCacheConfig = cacheConfig;
    }
    _parsers.addAll(parsers);
    _actionParsers.addAll(actionParsers);
    StacRegistry.instance.registerAll(_parsers, override);
    StacRegistry.instance.registerAllActions(_actionParsers, override);
    StacNetworkService.initialize(dio ?? Dio());
    _showErrorWidgets = showErrorWidgets;
    _logStackTraces = logStackTraces;
    _errorWidgetBuilder = errorWidgetBuilder;
  }

  static Widget? fromJson(Map<String, dynamic>? json, BuildContext context) {
    try {
      if (json == null) {
        return null;
      }

      // Safely extract widget type with validation
      final widgetType = json['type'];
      if (widgetType == null) {
        throw FormatException('Missing required "type" field in JSON');
      }

      if (widgetType is! String) {
        throw TypeError();
      }

      final stacParser = StacRegistry.instance.getParser(widgetType);

      if (stacParser == null) {
        Log.w('Widget type [$widgetType] not supported');

        // Return error widget if enabled (debug-only)
        if (_showErrorWidgets && kDebugMode) {
          return _buildErrorWidget(
            context: context,
            error: StacError(
              type: widgetType,
              error: Exception(_errorWidgetTypeNotSupported),
              json: json,
            ),
          );
        }
        return null;
      }

      // Resolve variables in JSON (skip for setValue to avoid recursion)
      final resolvedJson = widgetType == WidgetType.setValue.name
          ? json
          : resolveVariablesInJson(json, StacRegistry.instance);

      final model = stacParser.getModel(resolvedJson);
      return _wrapWithAutomationId(stacParser.parse(context, model), resolvedJson);
    } catch (e, stackTrace) {
      // Log error with full context
      _logError(
        category: 'Widget Parse Error',
        type: json?['type']?.toString(),
        error: e,
        stackTrace: stackTrace,
      );

      // Return error widget if enabled (debug-only)
      if (_showErrorWidgets && kDebugMode) {
        return _buildErrorWidget(
          context: context,
          error: StacError(
            type: json?['type']?.toString(),
            error: e,
            json: json,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    return null;
  }

  static Widget? fromStacWidget({
    required StacWidget widget,
    required BuildContext context,
  }) {
    try {
      final widgetType = widget.type;
      final stacParser = StacRegistry.instance.getParser(widgetType);

      if (stacParser == null) {
        Log.w('Widget type [$widgetType] not supported');

        // Return error widget if enabled (debug-only)
        if (_showErrorWidgets && kDebugMode) {
          return _buildErrorWidget(
            context: context,
            error: StacError(
              type: widgetType,
              error: Exception(_errorWidgetTypeNotSupported),
              json: widget.toJson(),
            ),
          );
        }
        return null;
      }

      // Resolve variables in JSON (skip for setValue to avoid recursion)
      final resolvedJson = widgetType == WidgetType.setValue.name
          ? widget.toJson()
          : resolveVariablesInJson(widget.toJson(), StacRegistry.instance);

      final model = stacParser.getModel(resolvedJson);
      return _wrapWithAutomationId(stacParser.parse(context, model), resolvedJson);
    } catch (e, stackTrace) {
      _logError(
        category: 'Widget Parse Error',
        type: widget.type,
        error: e,
        stackTrace: stackTrace,
      );

      // Return error widget if enabled (debug-only)
      if (_showErrorWidgets && kDebugMode) {
        return _buildErrorWidget(
          context: context,
          error: StacError(
            type: widget.type,
            error: e,
            json: widget.toJson(),
            stackTrace: stackTrace,
          ),
        );
      }
    }
    return null;
  }

  static FutureOr<dynamic> onCallFromJson(
    Map<String, dynamic>? json,
    BuildContext context,
  ) {
    try {
      if (json == null) {
        return null;
      }

      // Safely extract action type with validation
      final actionType = json['actionType'];
      if (actionType == null) {
        throw FormatException('Missing required "actionType" field in JSON');
      }

      if (actionType is! String) {
        throw TypeError();
      }

      final stacActionParser = StacRegistry.instance.getActionParser(
        actionType,
      );

      if (stacActionParser == null) {
        Log.w('Action type [$actionType] not supported');

        // Optionally show error widget for actions too (consistency)
        if (_showErrorWidgets && kDebugMode) {
          // Actions don't return widgets, so just log the error
          _logError(
            category: 'Action Parse Error',
            type: actionType,
            error: Exception(_errorActionTypeNotSupported),
          );
        }
        return null;
      }

      final model = stacActionParser.getModel(json);
      return stacActionParser.onCall(context, model);
    } catch (e, stackTrace) {
      _logError(
        category: 'Action Parse Error',
        type: json?['actionType']?.toString(),
        error: e,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  static Widget fromNetwork({
    required StacNetworkRequest request,
    required BuildContext context,
    LoadingWidgetBuilder? loadingWidget,
    ErrorWidgetBuilder? errorWidget,
  }) {
    return FutureBuilder<Response?>(
      future: StacNetworkService.request(context, request),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            Widget? widget;
            if (loadingWidget != null) {
              widget = loadingWidget(context);
              return widget;
            }
            break;
          case ConnectionState.done:
            if (snapshot.hasData) {
              final json = jsonDecode(snapshot.data.toString());
              return StacService.fromJson(json, context) ?? const SizedBox();
            } else if (snapshot.hasError) {
              _logError(
                category: 'Network Request Error',
                type: 'network',
                error: snapshot.error ?? 'Unknown network error',
                stackTrace: snapshot.stackTrace,
              );

              if (errorWidget != null) {
                return errorWidget(context, snapshot.error);
              } else if (_showErrorWidgets && kDebugMode) {
                return _buildErrorWidget(
                  context: context,
                  error: StacError(
                    type: 'network',
                    error: snapshot.error ?? 'Unknown network error',
                    stackTrace: snapshot.stackTrace,
                  ),
                );
              }
            }
            break;
          default:
            break;
        }
        return const SizedBox();
      },
    );
  }

  static Widget fromAssets(
    String assetPath, {
    LoadingWidgetBuilder? loadingWidget,
    ErrorWidgetBuilder? errorWidget,
  }) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            Widget? widget;
            if (loadingWidget != null) {
              widget = loadingWidget(context);
              return widget;
            }
            break;
          case ConnectionState.done:
            if (snapshot.hasData) {
              final json = jsonDecode(snapshot.data.toString());
              return StacService.fromJson(json, context) ?? const SizedBox();
            } else if (snapshot.hasError) {
              _logError(
                category: 'Asset Load Error',
                type: 'asset',
                error: snapshot.error ?? 'Unknown asset load error',
                stackTrace: snapshot.stackTrace,
              );

              if (errorWidget != null) {
                return errorWidget(context, snapshot.error);
              } else if (_showErrorWidgets && kDebugMode) {
                return _buildErrorWidget(
                  context: context,
                  error: StacError(
                    type: 'asset',
                    error: snapshot.error ?? 'Unknown asset load error',
                    stackTrace: snapshot.stackTrace,
                  ),
                );
              }
            }
            break;
          default:
            break;
        }
        return const SizedBox();
      },
    );
  }

  /// 给解析出的 widget 套一层 `Semantics(identifier:)`，让 UI 自动化能按 id
  /// 精确命中控件，而不是靠文字猜坐标。
  ///
  /// **为什么放在这里**：`fromJson` / `fromStacWidget` 是**所有** widget 解析
  /// 的唯一汇聚点。放在这里 = 每个控件自动获得能力，各 parser 无需改动，
  /// 协议也不用加新字段 —— JSON 里写 `"aid": "home.banner"` 即可。
  ///
  /// **为什么用 `Semantics.identifier` 而不是 `Key`**：`Key` 只活在 Flutter
  /// 的 widget 树里，`uiautomator dump` 看不到；`identifier` 会映射成
  /// Android 无障碍节点的 `resource-id`（`AccessibilityNodeInfo.setViewIdResourceName`），
  /// `adb shell uiautomator`、Appium、Maestro 都能直接按 id 定位。
  ///
  /// **为什么 `container: true`**：实测踩过。`container: false` 时 Semantics
  /// 会把属性**合并进子树**的语义节点；而一个可点区域下面通常有多个
  /// 语义节点（图标 + 多段文字），合并时 `identifier` 会丢失 ——
  /// 真机上表现为 `uiautomator dump` 里 `resource-id` 全空。
  /// `container: true` 会为这个可点区域建一个明确节点，identifier 落在它上面，
  /// 语义上也更准确（一个按钮 = 一个节点，而不是把按钮拆成几段文字）。
  ///
  /// **安全影响为零**：它只是给已有控件加一个可读标签，不改变可见性、
  /// 不改变点击行为、不引入任何数据通道。因此 release 构建也保留 ——
  /// 自动化验收需要它在正式包上可用。
  ///
  /// 没写 `aid` 的 widget 原样返回，不产生额外 widget 层级。
  static Widget? _wrapWithAutomationId(Widget? child, Map<String, dynamic> json) {
    if (child == null) return null;
    final aid = json['aid'];
    if (aid is! String || aid.isEmpty) return child;
    return Semantics(identifier: aid, container: true, child: child);
  }

  /// Centralized error logging with consistent formatting.
  static void _logError({
    required String category,
    String? type,
    required Object error,
    StackTrace? stackTrace,
  }) {
    // Build compact error message
    final buffer = StringBuffer('[Stac $category]');

    if (type != null) {
      buffer.write(' Type: "$type"');
    }

    buffer.write(' - $error');

    Log.e(buffer.toString());

    // Log stack trace separately if available and enabled
    if (_logStackTraces && stackTrace != null) {
      Log.e('Stack trace:\n$stackTrace');
    }
  }

  /// Builds an error widget with contextual information.
  ///
  /// Uses the custom [StacErrorWidgetBuilder] if provided during initialization,
  /// otherwise falls back to the default [StacErrorWidget].
  ///
  /// Only shown in debug mode when [_showErrorWidgets] is true.
  static Widget _buildErrorWidget({
    required BuildContext context,
    required StacError error,
  }) {
    // Prefer custom builder if provided
    if (_errorWidgetBuilder != null) {
      return _errorWidgetBuilder!(context, error);
    }

    return StacErrorWidget(errorDetails: error);
  }
}
