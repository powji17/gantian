import 'package:flutter_test/flutter_test.dart';
import 'package:gantian/decision.dart';
import 'package:gantian/free_fire_detector.dart';

void main() {
  final now = DateTime(2026, 10, 27, 20, 0, 0);

  RemoteStatus remote(String status, {String? device, int heartbeatAgo = 10}) =>
      RemoteStatus(
        status: status,
        device: device,
        heartbeat: now.subtract(Duration(seconds: heartbeatAgo)),
      );

  SyncAction run(GameState game, RemoteStatus r, {DateTime? since}) =>
      decide(game: game, since: since, now: now, remote: r, me: 'HP A');

  test('akun bebas + game dibuka → klaim', () {
    expect(run(GameState.foreground, remote('FREE')), SyncAction.claimInUse);
  });

  test('HP B masih aktif + aku buka game → jangan timpa', () {
    expect(run(GameState.foreground, remote('IN_USE', device: 'HP B')),
        SyncAction.nothing);
  });

  test('heartbeat HP B basi → boleh ambil alih', () {
    expect(
        run(GameState.foreground,
            remote('IN_USE', device: 'HP B', heartbeatAgo: 300)),
        SyncAction.claimInUse);
  });

  test('aku pemilik, game di background 30 detik → BACKGROUND', () {
    final since = now.subtract(const Duration(seconds: 30));
    expect(
        run(GameState.background, remote('IN_USE', device: 'HP A'),
            since: since),
        SyncAction.markBackground);
  });

  test('aku pemilik, background 5 menit → lepas', () {
    final since = now.subtract(const Duration(minutes: 5));
    expect(
        run(GameState.background, remote('BACKGROUND', device: 'HP A'),
            since: since),
        SyncAction.release);
  });

  test('aku pemilik, game closed → lepas', () {
    expect(run(GameState.closed, remote('IN_USE', device: 'HP A')),
        SyncAction.release);
  });

  test('bukan pemilik, game di background → tidak ngapa-ngapain', () {
    final since = now.subtract(const Duration(seconds: 30));
    expect(
        run(GameState.background, remote('IN_USE', device: 'HP B'),
            since: since),
        SyncAction.nothing);
  });

  test('state belum diketahui, bukan pemilik → tidak ngapa-ngapain', () {
    expect(run(GameState.unknown, remote('FREE')), SyncAction.nothing);
  });
}