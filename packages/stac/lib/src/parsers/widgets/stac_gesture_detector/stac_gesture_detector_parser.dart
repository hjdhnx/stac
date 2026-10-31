import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:material_ui/material_ui.dart';
import 'package:stac/src/parsers/core/stac_action_parser.dart';
import 'package:stac/src/parsers/core/stac_widget_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_drag_start_behavior_parser.dart';
import 'package:stac/src/parsers/foundation/interaction/stac_hit_test_behavior_parser.dart';
import 'package:stac_core/stac_core.dart';
import 'package:stac_framework/stac_framework.dart';

/// Defaults for [StacGestureDetector.onSwipe] acceptance thresholds.
const double kStacSwipeMinDistance = 60;
const double kStacSwipeMinVelocity = 250;

class StacGestureDetectorParser extends StacParser<StacGestureDetector> {
  const StacGestureDetectorParser();

  @override
  String get type => WidgetType.gestureDetector.name;

  @override
  StacGestureDetector getModel(Map<String, dynamic> json) =>
      StacGestureDetector.fromJson(json);

  @override
  Widget parse(BuildContext context, StacGestureDetector model) {
    // `onSwipe` needs horizontal drag accumulation across the gesture, so it
    // gets a stateful wrapper; plain detectors stay allocation-free.
    if (model.onSwipe == null) return _build(context, model);
    return _SwipeGestureDetector(model: model);
  }

  static Widget _build(
    BuildContext context,
    StacGestureDetector model, {
    void Function(DragStartDetails)? dragStart,
    void Function(DragUpdateDetails)? dragUpdate,
    void Function(DragEndDetails)? dragEnd,
    VoidCallback? dragCancel,
  }) {
    return GestureDetector(
      onTapDown: model.onTapDown != null
          ? (_) => model.onTapDown!.parse(context)
          : null,
      onTapUp: model.onTapUp != null
          ? (_) => model.onTapUp!.parse(context)
          : null,
      onTap: model.onTap != null ? () => model.onTap!.parse(context) : null,
      onTapCancel: model.onTapCancel != null
          ? () => model.onTapCancel!.parse(context)
          : null,
      onSecondaryTap: model.onSecondaryTap != null
          ? () => model.onSecondaryTap!.parse(context)
          : null,
      onSecondaryTapDown: model.onSecondaryTapDown != null
          ? (_) => model.onSecondaryTapDown!.parse(context)
          : null,
      onSecondaryTapUp: model.onSecondaryTapUp != null
          ? (_) => model.onSecondaryTapUp!.parse(context)
          : null,
      onSecondaryTapCancel: model.onSecondaryTapCancel != null
          ? () => model.onSecondaryTapCancel!.parse(context)
          : null,
      onTertiaryTapDown: model.onTertiaryTapDown != null
          ? (_) => model.onTertiaryTapDown!.parse(context)
          : null,
      onTertiaryTapUp: model.onTertiaryTapUp != null
          ? (_) => model.onTertiaryTapUp!.parse(context)
          : null,
      onTertiaryTapCancel: model.onTertiaryTapCancel != null
          ? () => model.onTertiaryTapCancel!.parse(context)
          : null,
      onDoubleTapDown: model.onDoubleTapDown != null
          ? (_) => model.onDoubleTapDown!.parse(context)
          : null,
      onDoubleTap: model.onDoubleTap != null
          ? () => model.onDoubleTap!.parse(context)
          : null,
      onDoubleTapCancel: model.onDoubleTapCancel != null
          ? () => model.onDoubleTapCancel!.parse(context)
          : null,
      onLongPressDown: model.onLongPressDown != null
          ? (_) => model.onLongPressDown!.parse(context)
          : null,
      onLongPressCancel: model.onLongPressCancel != null
          ? () => model.onLongPressCancel!.parse(context)
          : null,
      onLongPress: model.onLongPress != null
          ? () => model.onLongPress!.parse(context)
          : null,
      onLongPressStart: model.onLongPressStart != null
          ? (_) => model.onLongPressStart!.parse(context)
          : null,
      onLongPressMoveUpdate: model.onLongPressMoveUpdate != null
          ? (_) => model.onLongPressMoveUpdate!.parse(context)
          : null,
      onLongPressUp: model.onLongPressUp != null
          ? () => model.onLongPressUp!.parse(context)
          : null,
      onLongPressEnd: model.onLongPressEnd != null
          ? (_) => model.onLongPressEnd!.parse(context)
          : null,
      onSecondaryLongPressDown: model.onSecondaryLongPressDown != null
          ? (_) => model.onSecondaryLongPressDown!.parse(context)
          : null,
      onSecondaryLongPressCancel: model.onSecondaryLongPressCancel != null
          ? () => model.onSecondaryLongPressCancel!.parse(context)
          : null,
      onSecondaryLongPress: model.onSecondaryLongPress != null
          ? () => model.onSecondaryLongPress!.parse(context)
          : null,
      onSecondaryLongPressStart: model.onSecondaryLongPressStart != null
          ? (_) => model.onSecondaryLongPressStart!.parse(context)
          : null,
      onSecondaryLongPressMoveUpdate:
          model.onSecondaryLongPressMoveUpdate != null
          ? (_) => model.onSecondaryLongPressMoveUpdate!.parse(context)
          : null,
      onSecondaryLongPressUp: model.onSecondaryLongPressUp != null
          ? () => model.onSecondaryLongPressUp!.parse(context)
          : null,
      onSecondaryLongPressEnd: model.onSecondaryLongPressEnd != null
          ? (_) => model.onSecondaryLongPressEnd!.parse(context)
          : null,
      onTertiaryLongPressDown: model.onTertiaryLongPressDown != null
          ? (_) => model.onTertiaryLongPressDown!.parse(context)
          : null,
      onTertiaryLongPressCancel: model.onTertiaryLongPressCancel != null
          ? () => model.onTertiaryLongPressCancel!.parse(context)
          : null,
      onTertiaryLongPress: model.onTertiaryLongPress != null
          ? () => model.onTertiaryLongPress!.parse(context)
          : null,
      onTertiaryLongPressStart: model.onTertiaryLongPressStart != null
          ? (_) => model.onTertiaryLongPressStart!.parse(context)
          : null,
      onTertiaryLongPressMoveUpdate: model.onTertiaryLongPressMoveUpdate != null
          ? (_) => model.onTertiaryLongPressMoveUpdate!.parse(context)
          : null,
      onTertiaryLongPressUp: model.onTertiaryLongPressUp != null
          ? () => model.onTertiaryLongPressUp!.parse(context)
          : null,
      onTertiaryLongPressEnd: model.onTertiaryLongPressEnd != null
          ? (_) => model.onTertiaryLongPressEnd!.parse(context)
          : null,
      onVerticalDragDown: model.onVerticalDragDown != null
          ? (_) => model.onVerticalDragDown!.parse(context)
          : null,
      onVerticalDragStart: model.onVerticalDragStart != null
          ? (_) => model.onVerticalDragStart!.parse(context)
          : null,
      onVerticalDragUpdate: model.onVerticalDragUpdate != null
          ? (_) => model.onVerticalDragUpdate!.parse(context)
          : null,
      onVerticalDragEnd: model.onVerticalDragEnd != null
          ? (_) => model.onVerticalDragEnd!.parse(context)
          : null,
      onVerticalDragCancel: model.onVerticalDragCancel != null
          ? () => model.onVerticalDragCancel!.parse(context)
          : null,
      onHorizontalDragDown: model.onHorizontalDragDown != null
          ? (_) => model.onHorizontalDragDown!.parse(context)
          : null,
      // Only register a horizontal recognizer when something consumes it —
      // an unconditional recognizer would compete with scrollables in the
      // gesture arena for plain detectors.
      onHorizontalDragStart:
          model.onHorizontalDragStart == null && dragStart == null
          ? null
          : (details) {
              dragStart?.call(details);
              model.onHorizontalDragStart?.parse(context);
            },
      onHorizontalDragUpdate:
          model.onHorizontalDragUpdate == null && dragUpdate == null
          ? null
          : (details) {
              dragUpdate?.call(details);
              model.onHorizontalDragUpdate?.parse(context);
            },
      onHorizontalDragEnd: model.onHorizontalDragEnd == null && dragEnd == null
          ? null
          : (details) {
              dragEnd?.call(details);
              model.onHorizontalDragEnd?.parse(context);
            },
      onHorizontalDragCancel:
          model.onHorizontalDragCancel == null && dragCancel == null
          ? null
          : () {
              dragCancel?.call();
              model.onHorizontalDragCancel?.parse(context);
            },
      onForcePressStart: model.onForcePressStart != null
          ? (_) => model.onForcePressStart!.parse(context)
          : null,
      onForcePressPeak: model.onForcePressPeak != null
          ? (_) => model.onForcePressPeak!.parse(context)
          : null,
      onForcePressUpdate: model.onForcePressUpdate != null
          ? (_) => model.onForcePressUpdate!.parse(context)
          : null,
      onForcePressEnd: model.onForcePressEnd != null
          ? (_) => model.onForcePressEnd!.parse(context)
          : null,
      onPanDown: model.onPanDown != null
          ? (_) => model.onPanDown!.parse(context)
          : null,
      onPanStart: model.onPanStart != null
          ? (_) => model.onPanStart!.parse(context)
          : null,
      onPanUpdate: model.onPanUpdate != null
          ? (_) => model.onPanUpdate!.parse(context)
          : null,
      onPanEnd: model.onPanEnd != null
          ? (_) => model.onPanEnd!.parse(context)
          : null,
      onPanCancel: model.onPanCancel != null
          ? () => model.onPanCancel!.parse(context)
          : null,
      onScaleStart: model.onScaleStart != null
          ? (_) => model.onScaleStart!.parse(context)
          : null,
      onScaleUpdate: model.onScaleUpdate != null
          ? (_) => model.onScaleUpdate!.parse(context)
          : null,
      onScaleEnd: model.onScaleEnd != null
          ? (_) => model.onScaleEnd!.parse(context)
          : null,
      behavior: model.behavior?.parse,
      excludeFromSemantics: model.excludeFromSemantics ?? false,
      dragStartBehavior:
          model.dragStartBehavior?.parse ?? DragStartBehavior.start,
      child: model.child.parse(context),
    );
  }
}

/// Accumulates horizontal displacement and dispatches `onSwipe` when either
/// threshold is met. Direction lives in `dx`'s sign, so the action itself stays
/// business-agnostic.
class _SwipeGestureDetector extends StatefulWidget {
  const _SwipeGestureDetector({required this.model});

  final StacGestureDetector model;

  @override
  State<_SwipeGestureDetector> createState() => _SwipeGestureDetectorState();
}

class _SwipeGestureDetectorState extends State<_SwipeGestureDetector> {
  double _dx = 0;

  void _reset(DragStartDetails _) => _dx = 0;

  void _accumulate(DragUpdateDetails details) => _dx += details.delta.dx;

  void _settle(DragEndDetails details, BuildContext context) {
    final model = widget.model;
    final dx = _dx;
    final velocity = details.primaryVelocity ?? 0;
    _dx = 0;
    final minDistance = model.swipeMinDistance ?? kStacSwipeMinDistance;
    final minVelocity = model.swipeMinVelocity ?? kStacSwipeMinVelocity;
    if (dx.abs() < minDistance && velocity.abs() < minVelocity) return;
    final json = model.onSwipe!.toJson();
    final rawArgs = json['args'];
    final args = <String, dynamic>{
      if (rawArgs is Map) ...Map<String, dynamic>.from(rawArgs),
      'dx': dx,
      'velocity': velocity,
    };
    StacAction(jsonData: {...json, 'args': args}).parse(context);
  }

  @override
  Widget build(BuildContext context) {
    return StacGestureDetectorParser._build(
      context,
      widget.model,
      dragStart: _reset,
      dragUpdate: _accumulate,
      dragEnd: (details) => _settle(details, context),
      dragCancel: () => _dx = 0,
    );
  }
}
