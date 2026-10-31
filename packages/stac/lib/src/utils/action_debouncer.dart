import 'dart:async';

/// 尾触发节流器：把高频回调（拖动、输入）收敛成低频动作派发。
///
/// 典型用法：`schedule(ms, () => action.parse(context))`——每次调用都取消
/// 上一个未触发的回调，安静 [ms] 毫秒后才真正执行。
class ActionDebouncer {
  Timer? _timer;

  bool get isScheduled => _timer?.isActive ?? false;

  /// [milliseconds] 为空或 <= 0 时立即执行；> 0 时按尾触发延迟执行。
  void schedule(int? milliseconds, void Function() action) {
    cancel();
    if (milliseconds == null || milliseconds <= 0) {
      action();
      return;
    }
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      _timer = null;
      action();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
