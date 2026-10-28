String formatDurasi(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 1) return '<1 menit';
  if (d.inMinutes < 60) return '${d.inMinutes} menit';
  final jam = d.inHours;
  final menit = d.inMinutes % 60;
  return menit == 0 ? '$jam jam' : '$jam jam $menit menit';
}

String labelHari(DateTime d, DateTime now) {
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(now.year, now.month, now.day);
  final selisih = b.difference(a).inDays;
  if (selisih == 0) return 'Hari ini';
  if (selisih == 1) return 'Kemarin';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}