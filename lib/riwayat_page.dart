import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'account_status.dart';
import 'format.dart';
import 'sesi.dart';
import 'status_repository.dart';

class RiwayatPage extends StatelessWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat pemakaian')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: StatusRepository.doc.snapshots(),
        builder: (context, statusSnap) {
          final status = AccountStatus.fromData(statusSnap.data?.data());
          final aktifId =
              status.state == AccountState.free ? null : status.sessionId;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('sesi')
                .orderBy('start', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final daftar = snap.data!.docs.map(Sesi.fromDoc).toList();
              if (daftar.isEmpty) {
                return const Center(child: Text('Belum ada riwayat.'));
              }
              return _Isi(daftar: daftar, aktifId: aktifId);
            },
          );
        },
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.daftar, required this.aktifId});

  final List<Sesi> daftar;
  final String? aktifId;

  String _jam(BuildContext context, DateTime d) =>
      TimeOfDay.fromDateTime(d).format(context);

  String _keterangan(BuildContext context, Sesi s) {
    if (s.id == aktifId) return 'sejak ${_jam(context, s.start)} · berlangsung';
    final end = s.end;
    if (end == null) return '${_jam(context, s.start)} · tidak lengkap';
    final rentang = '${_jam(context, s.start)} – ${_jam(context, end)}';
    return s.alasan == 'putus' ? '$rentang · koneksi terputus' : rentang;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;

    final total = totalPerDevice(
      daftar,
      now: now,
      window: const Duration(days: 7),
      aktifId: aktifId,
    );
    final urut = total.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final terbesar = urut.isEmpty ? Duration.zero : urut.first.value;

    final children = <Widget>[
      Text('7 hari terakhir', style: text.titleMedium),
      const SizedBox(height: 8),
      if (urut.isEmpty) const Text('Belum ada sesi yang selesai.'),
      for (final e in urut)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(e.key), Text(formatDurasi(e.value))],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: terbesar.inSeconds == 0
                    ? 0
                    : e.value.inSeconds / terbesar.inSeconds,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      const Divider(height: 32),
    ];

    String? hariTerakhir;
    for (final s in daftar) {
      final hari = labelHari(s.start, now);
      if (hari != hariTerakhir) {
        hariTerakhir = hari;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(hari, style: text.titleSmall),
        ));
      }
      final selesai = s.end != null || s.id == aktifId;
      children.add(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
            s.id == aktifId ? Icons.sports_esports_rounded : Icons.history),
        title: Text(s.device),
        subtitle: Text(_keterangan(context, s)),
        trailing: Text(selesai ? formatDurasi(s.durasi(now)) : '—'),
      ));
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}