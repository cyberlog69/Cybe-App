class ClipboardService {
  static final List<String> _history = [];

  static List<String> get history => List.unmodifiable(_history);

  static void addClip(String text) {
    if (text.isEmpty) return;
    _history.remove(text);
    _history.insert(0, text);
    if (_history.length > 10) {
      _history.removeLast();
    }
  }

  static void clearHistory() {
    _history.clear();
  }
}
