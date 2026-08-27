class AsyncActionGuard {
  bool _running = false;

  bool get isRunning => _running;

  Future<T?> run<T>(Future<T> Function() action) async {
    if (_running) return null;
    _running = true;
    try {
      return await action();
    } finally {
      _running = false;
    }
  }
}
