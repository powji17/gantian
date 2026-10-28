import 'free_fire_detector.dart';

const backgroundGrace = Duration(minutes: 1);

class RemoteStatus {
  const RemoteStatus({required this.status, this.device, this.heartbeat});

  final String status; // FREE / IN_USE / BACKGROUND
  final String? device;
  final DateTime? heartbeat;

  bool isFree(DateTime now, Duration stale) =>
      status == 'FREE' ||
      heartbeat == null ||
      now.difference(heartbeat!) > stale;
}

enum SyncAction { nothing, claimInUse, markBackground, release }

SyncAction decide({
  required GameState game,
  required DateTime? since,
  required DateTime now,
  required RemoteStatus remote,
  required String me,
  Duration grace = backgroundGrace,
  Duration stale = const Duration(minutes: 2),
}) {
  final free = remote.isFree(now, stale);
  final mine = remote.device == me && remote.status != 'FREE';
  final canTake = free || mine;

  final inBackgroundWindow = game == GameState.background &&
      since != null &&
      now.difference(since) < grace;

  if (game == GameState.foreground) {
    // Kalau orang lain masih aktif memakai akun, jangan ditimpa.
    return canTake ? SyncAction.claimInUse : SyncAction.nothing;
  }
  if (inBackgroundWindow) {
    return mine ? SyncAction.markBackground : SyncAction.nothing;
  }
  return mine ? SyncAction.release : SyncAction.nothing;
}