import 'package:cloud_firestore/cloud_firestore.dart';

import 'decision.dart';
import 'free_fire_detector.dart';
import 'status_repository.dart';

enum _Want { none, foreground, background }

class AccountSync {
  AccountSync({required this.deviceName});

  final String deviceName;
  final detector = FreeFireDetector();

  static const _heartbeatEvery = Duration(seconds: 30);
  static const _stale = Duration(minutes: 2); // samakan dengan default decide()

  bool _owner = false;
  _Want? _lastWant;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);

  CollectionReference<Map<String, dynamic>> get _sesi =>
      FirebaseFirestore.instance.collection('sesi');

  _Want _want(DateTime now) {
    if (detector.state == GameState.foreground) return _Want.foreground;
    final since = detector.since;
    if (detector.state == GameState.background &&
        since != null &&
        now.difference(since) < backgroundGrace) {
      return _Want.background;
    }
    return _Want.none;
  }

  /// Dipanggil sering (±5 detik). Hanya menyentuh Firestore kalau perlu.
  Future<SyncAction?> tick() async {
    await detector.poll();
    final now = DateTime.now();
    final want = _want(now);

    if (want == _Want.none && !_owner) {
      _lastWant = want;
      return null;
    }

    final berubah = want != _lastWant;
    final saatnyaDetak = now.difference(_lastSync) >= _heartbeatEvery;
    if (!berubah && !saatnyaDetak) return null;

    _lastWant = want;
    _lastSync = now;
    final action = await sync();
    _owner =
        action == SyncAction.claimInUse || action == SyncAction.markBackground;
    return action;
  }

  Map<String, Object?> _bebas(FieldValue beat) => {
        'status': 'FREE',
        'lastHeartbeat': beat,
        'sessionId': FieldValue.delete(),
        'backgroundSince': FieldValue.delete(),
      };

  /// Menutup sesi kalau ada dan belum ditutup.
  void _tutupSesi(
    Transaction tx,
    DocumentSnapshot<Map<String, dynamic>>? sesi, {
    required DateTime end,
    required String alasan,
  }) {
    if (sesi == null || !sesi.exists) return;
    if (sesi.data()?['end'] != null) return; // sudah ditutup
    tx.update(sesi.reference, {'end': Timestamp.fromDate(end), 'alasan': alasan});
  }

  Future<SyncAction> sync() async {
    await detector.poll();
    late SyncAction action;
    final statusRef = StatusRepository.doc;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final now = DateTime.now();
      final data = (await tx.get(statusRef)).data();
      final remote = RemoteStatus(
        status: data?['status'] as String? ?? 'FREE',
        device: data?['device'] as String?,
        heartbeat: (data?['lastHeartbeat'] as Timestamp?)?.toDate(),
      );
      final sessionId = data?['sessionId'] as String?;
      final backgroundSince =
          (data?['backgroundSince'] as Timestamp?)?.toDate();

      action = decide(
        game: detector.state,
        since: detector.since,
        now: now,
        remote: remote,
        me: deviceName,
      );

      // Sesi berlanjut kalau aku pemilik dan detakku masih segar.
      final lanjut = remote.device == deviceName && !remote.isFree(now, _stale);
      final mulaiSesiBaru = !lanjut || sessionId == null;

      // ---- BACA dulu (semua read harus sebelum write) ----
      DocumentSnapshot<Map<String, dynamic>>? sesiLama;
      final perluBacaSesi = sessionId != null &&
          ((action == SyncAction.claimInUse && mulaiSesiBaru) ||
              action == SyncAction.release);
      if (perluBacaSesi) sesiLama = await tx.get(_sesi.doc(sessionId));

      // ---- TULIS ----
      final beat = FieldValue.serverTimestamp();
      switch (action) {
        case SyncAction.claimInUse:
          if (!mulaiSesiBaru) {
            tx.set(
              statusRef,
              {
                'status': 'IN_USE',
                'lastHeartbeat': beat,
                'backgroundSince': FieldValue.delete(),
              },
              SetOptions(merge: true),
            );
          } else {
            // Tutup sesi menggantung milik pemilik sebelumnya (kalau ada).
            _tutupSesi(
              tx,
              sesiLama,
              end: backgroundSince ?? remote.heartbeat ?? now,
              alasan: 'putus',
            );
            final baru = _sesi.doc();
            tx.set(baru, {'device': deviceName, 'start': beat, 'end': null});
            tx.set(
              statusRef,
              {
                'status': 'IN_USE',
                'device': deviceName,
                'since': beat,
                'sessionId': baru.id,
                'lastHeartbeat': beat,
                'backgroundSince': FieldValue.delete(),
              },
              SetOptions(merge: true),
            );
          }
        case SyncAction.markBackground:
          tx.set(
            statusRef,
            {
              'status': 'BACKGROUND',
              'lastHeartbeat': beat,
              'backgroundSince': Timestamp.fromDate(detector.since ?? now),
            },
            SetOptions(merge: true),
          );
        case SyncAction.release:
          _tutupSesi(
            tx,
            sesiLama,
            end: backgroundSince ?? detector.since ?? now,
            alasan: 'otomatis',
          );
          tx.set(statusRef, _bebas(beat), SetOptions(merge: true));
        case SyncAction.nothing:
          break;
      }
    });
    return action;
  }

  /// Dipakai tombol "Saya selesai" dan saat service dimatikan.
  Future<void> releaseIfMine({String alasan = 'selesai'}) async {
    final statusRef = StatusRepository.doc;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final data = (await tx.get(statusRef)).data();
      if (data?['device'] != deviceName || data?['status'] == 'FREE') return;

      final sessionId = data?['sessionId'] as String?;
      final backgroundSince =
          (data?['backgroundSince'] as Timestamp?)?.toDate();
      final sesi =
          sessionId == null ? null : await tx.get(_sesi.doc(sessionId));

      _tutupSesi(tx, sesi,
          end: backgroundSince ?? DateTime.now(), alasan: alasan);
      tx.set(statusRef, _bebas(FieldValue.serverTimestamp()),
          SetOptions(merge: true));
    });
    _owner = false;
  }
}