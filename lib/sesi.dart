import 'package:cloud_firestore/cloud_firestore.dart';

class Sesi {
  const Sesi({
    required this.id,
    required this.device,
    required this.start,
    this.end,
    this.alasan,
  });

  final String id;
  final String device;
  final DateTime start;
  final DateTime? end;
  final String? alasan;

  factory Sesi.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return Sesi(
      id: doc.id,
      device: m['device'] as String? ?? '?',
      // Tulisan lokal yang belum dikonfirmasi server belum punya timestamp.
      start: (m['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (m['end'] as Timestamp?)?.toDate(),
      alasan: m['alasan'] as String?,
    );
  }

  Duration durasi(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Total waktu main per device untuk sesi yang MULAI dalam [window] terakhir.
/// Sesi tanpa `end` hanya dihitung kalau itu sesi yang sedang aktif;
/// selain itu dilewati supaya kita tidak mengarang durasi.
Map<String, Duration> totalPerDevice(
  List<Sesi> daftar, {
  required DateTime now,
  required Duration window,
  String? aktifId,
}) {
  final batas = now.subtract(window);
  final hasil = <String, Duration>{};
  for (final s in daftar) {
    if (s.start.isBefore(batas)) continue;
    if (s.end == null && s.id != aktifId) continue;
    hasil[s.device] = (hasil[s.device] ?? Duration.zero) + s.durasi(now);
  }
  return hasil;
}