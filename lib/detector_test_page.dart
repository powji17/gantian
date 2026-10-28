import 'package:flutter/material.dart';

import 'free_fire_detector.dart';
import 'account_sync.dart';
import 'device_name.dart';

class DetectorTestPage extends StatefulWidget {
  const DetectorTestPage({super.key});

  @override
  State<DetectorTestPage> createState() => _DetectorTestPageState();
}

class _DetectorTestPageState extends State<DetectorTestPage>
    with WidgetsBindingObserver {
  final _detector = FreeFireDetector();
  bool _granted = false;
  String _kesimpulan = '-';
  List<String> _lines = [];
  String _aksi = '-';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Dipanggil saat kembali dari layar pengaturan sistem.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final ok = await _detector.hasPermission();
    if (mounted) setState(() => _granted = ok);
  }

  String _fmt(DateTime? d) =>
      d == null ? '?' : d.toLocal().toString().substring(11, 19);

  Future<void> _baca() async {
    final events = await _detector.recentEvents(const Duration(minutes: 60));
    final kesimpulan = await FreeFireDetector().poll();
    if (!mounted) return;
    setState(() {
      _kesimpulan = kesimpulan.name;
      _lines = [
        for (final e in events)
          '${_fmt(e.timeStampDate)}  ${e.eventTypeDescription}  ${e.packageName}',
      ].reversed.toList(); // terbaru di atas
    });
  }

  Future<void> _sinkron() async {
    final name = await DeviceName.load();
    if (name == null) return;
    final action = await AccountSync(deviceName: name).sync();
    if (mounted) setState(() => _aksi = action.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uji deteksi Free Fire')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_granted
                ? 'Izin Usage Access: aktif ✅'
                : 'Izin Usage Access: belum aktif ❌'),
            const SizedBox(height: 8),
            if (!_granted)
              FilledButton(
                onPressed: _detector.openSettings,
                child: const Text('Buka pengaturan Usage Access'),
              )
            else
              FilledButton(
                onPressed: _baca,
                child: const Text('Baca event Free Fire (60 menit terakhir)'),
              ),
            const SizedBox(height: 16),
            Text('Kesimpulan: $_kesimpulan',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _granted ? _sinkron : null,
              child: const Text('Sinkron sekarang'),
            ),
            Text('Aksi terakhir: $_aksi'),
            const SizedBox(height: 8),
            const Text('Event mentah (terbaru di atas):'),
            Expanded(
              child: ListView(
                children: [for (final l in _lines) Text(l)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}