import 'package:usage_stats/usage_stats.dart';

enum GameState { unknown, foreground, background, closed }

class FreeFireDetector {
  static const packages = {'com.dts.freefireth', 'com.dts.freefiremax'};

  GameState state = GameState.unknown;
  DateTime? since;
  DateTime? _lastQuery;

  Future<bool> hasPermission() async =>
      (await UsageStats.checkUsagePermission()) ?? false;

  Future<void> openSettings() async {
    await UsageStats.openUsageAccessSettings();
  }

  Future<List<EventUsageInfo>> _freeFireEvents(DateTime from, DateTime to) async {
    final events = await UsageStats.queryEvents(from, to);
    return events.where((e) => packages.contains(e.packageName)).toList();
  }

  /// Event mentah Free Fire dalam rentang [window] terakhir (untuk uji).
  Future<List<EventUsageInfo>> recentEvents(Duration window) {
    final now = DateTime.now();
    return _freeFireEvents(now.subtract(window), now);
  }

  /// Baca event baru, perbarui [state], lalu kembalikan state terbaru.
  /// Pemanggilan pertama melihat 6 jam ke belakang untuk menentukan state awal.
  Future<GameState> poll() async {
    final now = DateTime.now();
    final from = _lastQuery?.subtract(const Duration(seconds: 10)) ??
        now.subtract(const Duration(hours: 6));

    final events = await _freeFireEvents(from, now);
    for (final e in events) {
      final next = switch (e.eventTypeValue) {
        1 => GameState.foreground,
        2 || 23 => GameState.background,
        24 => GameState.closed,
        _ => null,
      };
      if (next == null) continue;
      state = next;
      since = e.timeStampDate ?? since;
    }
    _lastQuery = now;
    return state;
  }
}