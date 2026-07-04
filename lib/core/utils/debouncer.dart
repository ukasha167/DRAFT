import 'dart:async';

/// Debounces calls to [run] — the callback fires only after [delay] has elapsed
/// with no further calls. Cancel with [dispose].
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
