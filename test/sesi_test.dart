import 'package:flutter_test/flutter_test.dart';
import 'package:gantian/sesi.dart';

void main() {
  final now = DateTime(2026, 10, 28, 20, 0, 0);

  Sesi s(String id, String dev, DateTime start, {DateTime? end}) =>
      Sesi(id: id, device: dev, start: start, end: end);

  test('menjumlahkan durasi per device', () {
    final daftar = [
      s('1', 'HP A', now.subtract(const Duration(hours: 5)),
          end: now.subtract(const Duration(hours: 4))),
      s('2', 'HP A', now.subtract(const Duration(hours: 3)),
          end: now.subtract(const Duration(hours: 2, minutes: 30))),
      s('3', 'HP B', now.subtract(const Duration(hours: 2)),
          end: now.subtract(const Duration(hours: 1))),
    ];
    final total = totalPerDevice(daftar, now: now, window: const Duration(days: 7));
    expect(total['HP A'], const Duration(hours: 1, minutes: 30));
    expect(total['HP B'], const Duration(hours: 1));
  });

  test('sesi di luar 7 hari diabaikan', () {
    final daftar = [
      s('1', 'HP A', now.subtract(const Duration(days: 8)),
          end: now.subtract(const Duration(days: 8) - const Duration(hours: 1))),
    ];
    expect(totalPerDevice(daftar, now: now, window: const Duration(days: 7)), isEmpty);
  });

  test('sesi tanpa end yang bukan aktif tidak dikarang durasinya', () {
    final daftar = [s('1', 'HP A', now.subtract(const Duration(hours: 3)))];
    expect(totalPerDevice(daftar, now: now, window: const Duration(days: 7)), isEmpty);
  });

  test('sesi aktif dihitung sampai sekarang', () {
    final daftar = [s('1', 'HP A', now.subtract(const Duration(minutes: 20)))];
    final total = totalPerDevice(daftar,
        now: now, window: const Duration(days: 7), aktifId: '1');
    expect(total['HP A'], const Duration(minutes: 20));
  });

  test('durasi negatif (jam HP ngaco) dijadikan nol', () {
    final sesi = s('1', 'HP A', now, end: now.subtract(const Duration(minutes: 5)));
    expect(sesi.durasi(now), Duration.zero);
  });
}