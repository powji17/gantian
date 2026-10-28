import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountState { free, inUse, background }

class AccountStatus {
  const AccountStatus({
    required this.state,
    this.device,
    this.since,
    this.heartbeat,
    this.sessionId,
  });

  final AccountState state;
  final String? device;
  final DateTime? since;
  final DateTime? heartbeat;
  final String? sessionId;

  static const staleAfter = Duration(minutes: 2);

  factory AccountStatus.fromData(
    Map<String, dynamic>? data, {
    DateTime? now,
    bool pendingWrites = false,
  }) {
    if (data == null) return const AccountStatus(state: AccountState.free);

    final n = now ?? DateTime.now();
    final heartbeat = (data['lastHeartbeat'] as Timestamp?)?.toDate();

    // Tulisan lokal yang belum dikonfirmasi server belum punya timestamp:
    // anggap masih segar supaya layar tidak kedip jadi "bebas".
    final basi = heartbeat == null
        ? !pendingWrites
        : n.difference(heartbeat) > staleAfter;

    final raw = data['status'] as String? ?? 'FREE';
    final state = (raw == 'FREE' || basi)
        ? AccountState.free
        : raw == 'BACKGROUND'
            ? AccountState.background
            : AccountState.inUse;

    return AccountStatus(
      state: state,
      device: data['device'] as String?,
      since: (data['since'] as Timestamp?)?.toDate(),
      heartbeat: heartbeat,
      sessionId: data['sessionId'] as String?,
    );
  }

  bool isMine(String? me) =>
      state != AccountState.free && me != null && device == me;
}