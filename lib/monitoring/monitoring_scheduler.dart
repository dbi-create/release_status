import 'dart:async';

/// Runs [onTick] after a short startup delay, then on [pollInterval].
///
/// Widget tests must leave this disabled. A live timer prevents
/// `pumpAndSettle` from completing.
class MonitoringScheduler {
  MonitoringScheduler({
    required this.onTick,
    this.startupDelay = const Duration(seconds: 3),
    this.pollInterval = const Duration(minutes: 1),
  });

  final Future<void> Function() onTick;
  final Duration startupDelay;
  final Duration pollInterval;

  Timer? _timer;
  bool _disposed = false;
  bool _running = false;

  void start() {
    _schedule(startupDelay);
  }

  Future<void> tickNow() => _safeTick();

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (_disposed) {
      return;
    }
    _timer = Timer(delay, () async {
      await _safeTick();
      _schedule(pollInterval);
    });
  }

  Future<void> _safeTick() async {
    if (_disposed || _running) {
      return;
    }
    _running = true;
    try {
      await onTick();
    } finally {
      _running = false;
    }
  }
}
